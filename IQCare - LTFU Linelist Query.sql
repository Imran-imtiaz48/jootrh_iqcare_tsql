USE IQCare_CPAD
GO

DECLARE @endDate AS date;
DECLARE @startDate AS date;

set @startDate = DATEADD(MONTH, -12, GETDATE());
set @endDate = GETDATE();

set @endDate = '2019-09-26';
set @startDate = DATEADD(DAY, -6, @endDate);
--print @startDate
--return
BEGIN TRY
	drop table #tmpAllTreatment
	drop table #tmpAllVisits
	drop table #tmpAllpatients
	drop table #tmpLTFU
END TRY
BEGIN CATCH
END CATCH

exec pr_OpenDecryptedSession

;WITH all_treatment_cte AS (
		SELECT * FROM (
			SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
					INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
					 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
					)		
			 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate -- AND t.PatientId = 244

		) t
)

SELECT * 
INTO #tmpAllTreatment
FROM all_treatment_cte 

;WITH providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 --or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
),

all_visits_cte AS (
	SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId, ProviderName,UserId,GroupId FROM (
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID,ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY VisitDate DESC) as RowNum FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, e.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
			--UNION
			--SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			--UNION
			--SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			--WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId -- WHERE v.PatientId = 244
	) visits WHERE VisitDate < = @endDate AND RowNum = 1
)

SELECT * 
INTO #tmpAllVisits
FROM all_visits_cte 

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

exec pr_OpenDecryptedSession;

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.ptn_pk as PatientPk, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,UPPER(tp.ContactName) AS ContactName, EnrollmentNumber, 
--UPPER( tpm.PatientName) 
UPPER(CONCAT(g.FirstName, ' ', REPLACE(g.MiddleName, char(0),'') , ' ', g.LastName))
AS PatientName, 
CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, MaritalStatus, EducationLevel,ce.ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
--INNER JOIN PatientContact
 LEFT JOIN (
	SELECT PatientId,ExitReason,ExitDate,TransferOutfacility,CreatedBy FROM (
		SELECT ce.PatientId,l.Name AS ExitReason,ExitDate,TransferOutfacility,CreatedBy,ROW_NUMBER() OVER (PARTITION BY ce.PatientId ORDER BY CreateDate DESC) as RowNum FROM patientcareending ce INNER JOIN LookupItem l ON
		l.Id = ce.ExitReason
		LEFT JOIN 		(
			SELECT 
				x.PatientId,
				CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
			FROM PatientAppointment X
			INNER JOIN PatientMasterVisit v ON x.PatientMasterVisitId = v.id
			WHERE CAST(v.VisitDate AS DATE) <= @endDate 
			GROUP BY X.PatientId
	) pa ON pa.PatientId = ce.PatientId
		WHERE ce.DeleteFlag = 0 AND ((pa.NextAppointmentDate < @endDate AND l.Name<>'Death' AND ce.ExitDate<=@endDate) OR (l.Name='Death' AND ce.ExitDate<=@endDate))
	) ce WHERE rowNum = 1
 ) ce ON g.Id = ce.PatientId
LEFT JOIN (
	SELECT PersonId, MobileNumber, AlternativeNumber,EmailAddress FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PersonId ORDER BY CreateDate) as RowNum, PC.PersonId, PC.MobileNumber, PC.AlternativeNumber,PC.EmailAddress FROM PersonContactView PC
	) pc1 WHERE pc1.RowNum = 1
) PC ON PC.PersonId = g.PersonId	
LEFT JOIN  (SELECT DISTINCT PatientPk,PatientName,ContactPhoneNumber,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
LEFT JOIN (
		SELECT 
			x.PatientId,
			CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
		FROM PatientAppointment X
		INNER JOIN PatientMasterVisit v ON x.PatientMasterVisitId = v.id
		WHERE CAST(v.VisitDate AS DATE) <= @endDate 
		GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
 -- WHERE p.PatientId = 244
 )

 SELECT * 
 INTO #tmpAllpatients
 FROM 
 all_Patients_cte


;WITH vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr WHERE RowNum = 1 
 ),

curr_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine, TLE400 FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenDate DESC,t.PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
		TLE400
		 FROM #tmpAllTreatment t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenDate) >= 2000 AND t.RegimenDate <= @endDate

	) t WHERE t.rowNum = 1
),

init_treatmenttracker_cte AS (
	SELECT TLE400,PatientMasterVisitId, PatientId,Regimen,RegimenId, t.ARTInitiationDate, Line as regimenLine FROM (
		SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenDate ASC, t.RegimenDate ASC,PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line ,
		TLE400		
		FROM #tmpAllTreatment t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenDate) >= 2000 AND t.RegimenDate <= @endDate --and t.RegimenStartDate IS NOT NULL
	) t WHERE t.rowNum = 1
),

prev_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine, TLE400 FROM (
		SELECT att.RegimenDate, att.PatientId, att.RegimenId, att.Regimen,  CASE WHEN att.RegimenLine LIKE '%First%' THEN '1' WHEN att.RegimenLine LIKE '%Second%' THEN '2' WHEN att.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
		t.TLE400, ROW_NUMBER() OVER(PARTITION BY att.PatientId ORDER BY att.RegimenDate DESC) as RowNum FROM curr_treatmenttracker_cte t 
		INNER JOIN #tmpAllTreatment att ON t.PatientId = att.PatientId AND t.RegimenId <> att.RegimenId 
	) t WHERE t.rowNum = 1
),

prev_regimen_date_cte AS (
	SELECT attx.PatientId, MIN(attx.RegimenDate) as Regimendate FROM #tmpAllTreatment attx 
		INNER JOIN prev_treatmenttracker_cte pttx ON attx.PatientId = pttx.PatientId AND pttx.RegimenId = attx.RegimenId
	GROUP BY attx.PatientId
),

curr_regimen_date_cte AS (
	SELECT attx.PatientId, MIN(attx.RegimenDate) as Regimendate FROM #tmpAllTreatment attx 
		INNER JOIN curr_treatmenttracker_cte pttx ON attx.PatientId = pttx.PatientId AND pttx.RegimenId = attx.RegimenId
	GROUP BY attx.PatientId
),

providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
/*
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, g.GroupName from mst_Groups g
		INNER JOIN lnk_UserGroup lg ON lg.GroupId = g.GroupID
		INNER JOIN mst_User u ON u.UserID = lg.UserID AND u.UserID > 1
		WHERE GroupName IN ('Nurses', 'Clinician')	
*/
),

last_visit_cte AS (
	SELECT lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, v.VisitDate AS LastVisitdate, PatientMasterVisitId, v.ProviderId AS lastProvider, ProviderName as LastProviderName FROM #tmpAllVisits v
--		INNER JOIN providers_cte p ON p.UserID = v.lastProvider
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId,v.UserID lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM #tmpAllVisits v INNER JOIN mst_User u ON v.UserId = u.UserID
	) lastVisit WHERE rowNum = 1
),

screening_cte AS (
	SELECT * from (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate DESC) as rowNum, PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
	) ps WHERE ps.rowNum =1
),


completed_ipt_cte AS (
	SELECT * FROM (
		SELECT icf.PatientId, ISNULL(li.DisplayName, '') AS IptStatus, iptw.IptStartDate, ipt.IptOutcomeDate as DateCompleted, ROW_NUMBER() OVER (PARTITION BY icf.PatientId ORDER BY icf.CreateDate DESC) as RowNum, CASE WHEN EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END as EverBeenOnIPt FROM PatientICF icf 
		LEFT JOIN PatientIptOutcome ipt ON ipt.PatientId = icf.PatientId  LEFT JOIN LookupItem li ON li.Id = ipt.IptEvent
		LEFT JOIN 
			(SELECT PatientId, MIN(IptStartDate) as IptStartDate
			 FROM PatientIptWorkup WHERE IptStartDate IS NOT NULL GROUP BY PatientId) 
			iptw ON iptw.PatientId = icf.PatientId
	) ipt WHERE ipt.RowNum = 1 
),


dc_cte AS (
	SELECT dc.PatientId,
		dc.ServiceArea
	FROM (SELECT PA.PatientId,
		PA.DifferentiatedCareId,
		V.VisitDate,
		l1.DisplayName AS ServiceArea,
		Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate DESC,
		PA.Description, PA.CreateDate DESC, PA.CreatedBy DESC) AS RowNum
		FROM PatientAppointment AS PA
		INNER JOIN PatientMasterVisit AS V ON V.Id = PA.PatientMasterVisitId
		INNER JOIN LookupItem AS l1 ON l1.Id = PA.ServiceAreaId
		WHERE V.VisitDate <= @endDate AND PA.DeleteFlag = 0 AND
		PA.DeleteFlag = 0) dc
	WHERE dc.RowNum = 1
),


ti_cte AS (
	select PatientId,TiNumber FROM (                                                
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY PatientId) AS rowNUm, PatientID, IdentifierValue as TINumber FROM PatientIdentifier WHERE IdentifierTypeId = 17
	) ti WHERE rowNUm = 1
),

mch_cte AS (
	select PatientId,MCHNumber,MCHEnrollmentDate FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber,CAST(ps.StartDate AS DATE) as MCHEnrollmentDate FROM mst_Patient M 
		INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk 
		LEFT JOIN Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk INNER JOIN mst_module modu ON ps.ModuleId = modu.ModuleID 
		WHERE  modu.ModuleId = 15 AND MCHID IS NOT NULL
	) ti WHERE rowNUm = 1
),


all_tca_cte AS (
		SELECT p.PatientId, CAST(AppointmentDate AS DATE) as AppointmentDate, CAST(VisitDate as DATE) as Visitdate, l.Name as VisitStatus FROM PatientAppointment p INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id 
		INNER JOIN LookupItem l ON L.Id = StatusId
		WHERE (VisitDate <= @endDate AND ABS(DATEDIFF(M,VisitDate, AppointmentDate)) <= 6) OR AppointmentDate <= @endDate
		UNION
		SELECT p.id as PatientId,CAST(AppDate AS DATE) as AppointmentDate,CAST(o.VisitDate AS DATE) as VisitDate, '' from dtl_PatientAppointment a INNER JOIN Patient p ON a.Ptn_pk = p.ptn_pk INNER JOIN ord_Visit o  ON o.Visit_Id = a.Visit_pk
		WHERE VisitDate <= @endDate -- AND VisitDate >= @startDate
),

last_tca_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY VisitDate DESC,AppointmentDate DESC) AS rowNUm, * FROM all_tca_cte 
	) tca WHERE rowNUm = 1
)




-- ALL PATIENTS
SELECT DISTINCT
/*a.PatientId as Id,*/ a.EnrollmentNumber as PatientId,ti.TINumber AS [JOOT TI Number],mch.mchNumber AS [MCH Number],a.PatientName AS [Name],a.sex AS Sex/*, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS [Patient Type]*/,a.currentAge AS [Current Age],  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, 
cttx.Regimen as [Current regimen],cttx.regimenLine as [Current regimen line], CAST(lv.lastVisitDate AS DATE) lastVisitDate,
CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, 
DATEADD(DAY,31,a.NextAppointmentDate) LTFUDate,
a.PhoneNumber,
a.ContactName,
a.ContactPhoneNumber,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) <= 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) > 30 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
a.ExitDate,
lv.LastProviderName,
dc.ServiceArea,
'                     ' Comments
/*for stans*/ 
INTO #tmpLTFU
FROM #tmpAllpatients a 
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.patientId = a.PatientID
LEFT JOIN dc_cte dc ON dc.PatientId = a.PatientID
--WHERE EnrollmentDate <= @endDate 
-- AND a.PatientID = 244

SELECT * FROM #tmpLTFU WHERE LTFUDate BETWEEN @startDate AND @endDate AND PatientStatus = 'LTFU'
return

select * from gcPatientView WHERE EnrollmentNumber = '13939-26157'

SELECT * FROM #tmpAllpatients WHERE PatientId = 10555 ORDER BY NextAppointmentDate DESC

select * from PatientMasterVisit WHERE PatientId = 48786

select * from PatientAppointment WHERE PatientId = 48786
