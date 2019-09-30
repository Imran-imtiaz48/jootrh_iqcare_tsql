DECLARE @startDate AS date; 
DECLARE @endDate AS date ;

set @startDate ='2018-06-01';
set @endDate ='2019-05-31';

BEGIN TRY
drop table #tmpAllTreatment
drop table #tmpAllVisits
drop table #tmpProviders
drop table #tmpUtilization
drop table #tmpStable
drop table #tmpDSD
drop table #tmpIpt
drop table #tmpInitTreatment
drop table #tmpAllPatients
END TRY
BEGIN CATCH
END CATCH

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

;WITH all_treatment_cte AS (
	SELECT * FROM (
		SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
		TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
				INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
				 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
				)		
		 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 --AND t.RegimenStartDate BETWEEN @StartDate AND @endDate
	) t
)

SELECT * 
INTO #tmpAllTreatment
FROM all_treatment_cte 

;WITH providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 --or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
)

SELECT ProviderName,UserId,GroupID 
INTO #tmpProviders
FROM providers_cte

;WITH all_visits_cte AS (
	SELECT v.*, u.ProviderName  FROM (
		SELECT PatientId,CAST(VisitDate AS DATE) as VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v WHERE VisitDate IS NOT NULL AND CAST(VisitDate AS DATE) < (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId)
		UNION
		SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  WHERE ScreeningTypeId = 4
	--	UNION All
	--	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientVitals
	--	UNION ALL
	--	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientAppointment
		) v INNER JOIN (
			SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID from mst_Groups g
			INNER JOIN lnk_UserGroup lg ON lg.GroupId = g.GroupID
			INNER JOIN mst_User u ON u.UserID = lg.UserID
			WHERE GroupName LIKE 'Clinician' 	
		) u ON v.lastProvider = u.UserID
		 WHERE v.VisitDate <= @endDate AND v.VisitDate >= @startDate
)

SELECT * 
INTO #tmpAllVisits
FROM all_visits_cte 

;WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, tp.PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, PatientStatus, ExitDate, DateOfBirth, PatientType
FROM            gcPatientView2 g
--INNER JOIN PatientContact
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster]) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN (
		SELECT PatientId,
		CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
-- WHERE g.PatientStatus = 'Death'
 )

 SELECT * 
INTO #tmpAllPatients
FROM all_Patients_cte 

;WITH vl_sample_cte AS (
	SELECT PatientId,SampleDate,VLResults,PatientMasterVisitId, CreatedBy AS VLSampleProvider FROM (
		SELECT        patientId,PatientMasterVisitId,CAST (SampleDate AS DATE) as SampleDate, ResultValues  as VLResults,CreatedBy,ROW_NUMBER() OVER (Partition By PatientId,PatientMasterVisitId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker l
		INNER JOIN #tmpProviders p ON p.UserID = l.CreatedBy
		WHERE   
		         (LabTestId = 3) AND (Reasons = 'Routine' OR Reasons = 'Baseline') AND SampleDate BETWEEN @startDate AND @endDate
	) vlr WHERE RowNum = 1
)

-- select * from PatientLabTracker WHERE REasons <> 'Routine'
	
-- ALL PATIENTS


SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,lv.VisitDate,vl.SampleDate,vl.VLSampleProvider, lv.ProviderName
INTO #tmpUtilization
FROM #tmpAllPatients a 
INNER JOIN #tmpAllVisits lv ON lv.PatientId = a.PatientID
LEFT JOIN vl_sample_cte vl ON vl.PatientMasterVisitId = lv.PatientMasterVisitId
--WHERE lv.PatientMasterVisitId = 183475


--select * from #tmpUtilization WHERE SampleDate IS NOT NULL

;WITH stable_cte AS (
	SELECT *
	FROM (
		SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY v.VisitDate DESC) AS rowNum,
		s.PatientId,
		CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
		END AS Categorization,
		v.VisitDate AS CategorizationDate, s.CreatedBy as CategorizationProvider, s.PatientMasterVisitId
		FROM PatientCategorization s
		INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
		--INNER JOIN #tmpProviders p ON p.UserID = s.CreatedBy
		WHERE v.VisitDate BETWEEN '2018-06-01' AND '2019-05-31'/* @startDate AND @endDate*/) s
	WHERE s.rowNum = 1
)

SELECT i.PatientId,v.ProviderName, i.CategorizationDate, i.Categorization
INTO #tmpStable 
FROM stable_cte i INNER JOIN
#tmpAllVisits v ON i.PatientMasterVisitId = v.PatientMasterVisitId
--WHERE i.Categorization = 'Stable'

drop table #tmpDSD
;WITH dc_current_cte AS (
	SELECT PatientId, DCModel,PatientMasterVisitId, CategorizingProvider,CreateDate AS DsdDate, DifferentiatedCareId FROM (
		SELECT        v.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,PA.PatientMasterVisitId,PA.CreatedBy AS CategorizingProvider,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY v.VisitDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		INNER JOIN #tmpAllVisits AS V ON V.PatientMasterVisitId = pa.PatientMasterVisitId
		WHERE v.VisitDate BETWEEN  '2018-06-01' AND '2019-05-31'-- @startDate AND @endDate
	) dc WHERE dc.RowNum = 1 AND dc.DifferentiatedCareId IN(237,236)  
),
dc_cte AS (
	SELECT PatientId, DCModel,PatientMasterVisitId, CategorizingProvider,CreateDate AS DsdDate, DifferentiatedCareId FROM (
		SELECT        V.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,PA.PatientMasterVisitId,PA.CreatedBy AS CategorizingProvider,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY v.VisitDate ASC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		INNER JOIN #tmpAllVisits AS V ON V.PatientMasterVisitId = pa.PatientMasterVisitId
		INNER JOIN dc_current_cte dcc ON dcc.PatientMasterVisitId = PA.PatientMasterVisitId
		WHERE PA.DifferentiatedCareId IN(237,236) --AND v.VisitDate BETWEEN  '2018-06-01' AND '2019-05-31'-- @startDate AND @endDate
	) dc WHERE dc.RowNum = 1
)


--select * from dc_cte i INNER JOIN
--#tmpAllVisits v ON i.PatientMasterVisitId = v.PatientMasterVisitId
--WHERE  i.DifferentiatedCareId <> 254
--select * from LookupItemView WHERE MasterId =68

SELECT i.PatientId,v.ProviderName, i.DsdDate 
INTO #tmpDSD 
FROM dc_cte i INNER JOIN
#tmpAllVisits v ON i.PatientMasterVisitId = v.PatientMasterVisitId
WHERE  i.DifferentiatedCareId IN(237,236) 

--select * from LookupItemView WHERE MasterId = 68
;WITH ipt_cte AS (
	SELECT * FROM (	
		SELECT ROW_NUMBER() OVER (PARTITION BY IPT.PatientId ORDER BY IPT.CreateDate DESC) as RowNum, IPT.patientId,IPT.IptStartDate, IPT.CreatedBy AS IPTProvider,PatientMasterVisitId 
		FROM PatientIptWorkup IPT
		INNER JOIN PatientMasterVisit AS V ON V.id = IPT.PatientMasterVisitId
		INNER JOIN #tmpProviders p ON p.UserID = IPT.CreatedBy
			WHERE v.VisitDate BETWEEN @startDate AND @endDate AND IPT.StartIpt  = 1
	) IPT WHERE ipt.RowNum = 1
)

SELECT i.PatientId,i.IptStartDate,v.ProviderName 
INTO #tmpIpt 
FROM ipt_cte i INNER JOIN
#tmpAllVisits v ON i.PatientMasterVisitId = v.PatientMasterVisitId

;WITH init_treatmenttracker_cte AS (
	SELECT TLE400,PatientMasterVisitId, PatientId,Regimen,RegimenId, t.ARTInitiationDate, Line as regimenLine FROM (
		SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenDate ASC, t.RegimenDate ASC,PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line ,
		TLE400		
		FROM #tmpAllTreatment t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenDate) >= 2000 --AND t.RegimenDate <= @endDate --and t.RegimenStartDate IS NOT NULL
	) t WHERE t.rowNum = 1
)

SELECT i.PatientId,i.ARTInitiationDate,v.ProviderName 
INTO #tmpInitTreatment
FROM init_treatmenttracker_cte i INNER JOIN
#tmpAllVisits v ON i.PatientMasterVisitId = v.PatientMasterVisitId
INNER JOIN #tmpAllPatients a ON a.PatientID = v.PatientId
WHERE a.PatientType = 258 AND i.ARTInitiationDate BETWEEN @startDate AND @endDate


return
/*
;WITH  all_vitals_cte AS (
	SELECT PatientId, PatientMasterVisitId,Weight,Height,VisitDate,BMI,BPDiastolic,BPSystolic FROM ( 
		SELECT ROW_NUMBER() OVER(PARTITION BY pmv.PatientId, CAST (vi.CreateDate AS DATE) ORDER BY vi.VisitDate) as RowNum,pmv.Id as PatientMasterVisitId, vi.Id as VitalsId, CAST (vi.CreateDate AS DATE) as VisitDate, vi.BPDiastolic,vi.BPSystolic,vi.BMI,vi.PatientId,vi.WeightForAge,vi.WeightForHeight,vi.BMIZ,vi.Weight,vi.Height FROM PatientVitals vi INNER JOIN PatientMasterVisit pmv  ON vi.PatientId = pmv.PatientId  
	) vit WHERE rowNUm = 1
 ),

completed_ipt_outcome_cte AS (
	SELECT PatientId, 'Y' AS CompletedIpt FROM  (
		SELECT io.PatientId, li.Name AS IptOutcome, ROW_NUMBER() OVER (PARTITION BY io.PatientId ORDER BY io.CreateDate DESC) AS rown FROM PatientIptOutcome io  LEFT JOIN PatientIptWorkup iw  ON iw.PatientId = io.PatientId 
		INNER JOIN LookupItem li ON li.Id = io.IptEvent
		WHERE IptEvent = 525
	) ipto WHERE ipto.rown = 1
),

stable_cte AS (
	SELECT *
	FROM (
		SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
		v.VisitDate DESC) AS rowNum,
		s.PatientId,
		CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
		END AS Categorization,
		ComputedCategorization = CASE WHEN vit.BMI>=18.5 THEN 'Stable' ELSE 'Unstable' END,
		v.VisitDate AS CategorizationDate, s.CreatedBy as CategorizationProvider, s.PatientMasterVisitId
		FROM PatientCategorization s
		INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
		LEFT JOIN all_vitals_cte vit ON vit.PatientMasterVisitId = v.Id 
		LEFT JOIN completed_ipt_outcome_cte ipt ON ipt.PatientId = 
		INNER JOIN #tmpProviders p ON p.UserID = s.CreatedBy
		WHERE v.VisitDate BETWEEN @startDate AND @endDate) s
	WHERE s.rowNum = 1
)
*/

select * from #tmpStable WHERE ProviderName = 'Hellen Ogege' --order by dsddate desc --WHERE SampleDate IS NOT NULL



SELECT ProviderName,SUM(CASE WHEN Categorization = 'Stable' THEN 1 ELSE 0 END) AS Stable, 
SUM(CASE WHEN Categorization = 'Unstable' THEN 1 ELSE 0 END) AS Unstable
FROM #tmpStable GROUP BY ProviderName
ORDER BY ProviderName

--select * from #tmpInitTreatment WHERE ProviderName LIKE '%susan%'

select ProviderName, COUNT(*) AS ARTInitaitions from #tmpInitTreatment 
GROUP BY ProviderName
ORDER BY ProviderName


select ProviderName, COUNT(*) AS Encounters from #tmpUtilization 
GROUP BY ProviderName
ORDER BY ProviderName

select ProviderName, SUM(CASE WHEN SampleDate IS NOT NULL THEN 1 ELSE 0 END) AS VLOrders from #tmpUtilization 
GROUP BY ProviderName
ORDER BY ProviderName

select * from #tmpDSD

select ProviderName, COUNT(*) AS Dsd from #tmpDSD 
GROUP BY ProviderName
ORDER BY ProviderName

select * from #tmpDSD WHERE ProviderName LIKE '%onywera%' order by dsdDate desc

--select * from gcPatientView WHERE id = 2216

select * from PatientAppointment WHERE PatientId = 11728 --order by 


select * from PatientCategorization WHERE PatientID = 4 ORDER BY Id DESC

	SELECT *
	FROM 
	(
	SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
		v.VisitDate DESC, s.id DESC) AS rowNum,
		s.PatientId,
		CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
		END AS Categorization,
		v.VisitDate AS CategorizationDate
		FROM PatientCategorization s
		INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
		WHERE v.DeleteFlag = 0 AND s.DeleteFlag = 0 AND v.VisitDate <= '2019-05-31' ) s
	WHERE s.PatientId = 4



		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId FROM (
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY VisitDate DESC) as RowNum FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= '2019-05-31')
			--UNION
			--SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			--UNION
			--SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			--WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
		) v 
	) visits WHERE PatientId = 18 VisitDate < = @endDate AND RowNum = 1
