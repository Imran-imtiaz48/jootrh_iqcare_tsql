DECLARE @startDate AS date; 
DECLARE @endDate AS date ;

set @startDate ='2018-03-01';
set @endDate ='2018-03-31';

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, tp.PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, PatientStatus, ExitDate, DateOfBirth, PatientType
FROM            gcPatientView2 g
--INNER JOIN PatientContact
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster]) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN (
		SELECT PatientId,
		CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId
 ),

 vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId,SampleDate ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr WHERE RowNum = 1
 ),

 pending_vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId,SampleDate ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Pending')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr -- WHERE RowNum = 1
 ),

vl_cte AS (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
											FROM            dbo.PatientLabTracker
											WHERE        (Results = 'Complete')
											AND         (LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
	) r WHERE r.RowNum = 1
),
second_last_vl_cte as (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VlResultsDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
											FROM            dbo.PatientLabTracker
											WHERE        (Results = 'Complete')
											AND         (LabTestId = 3)	AND SampleDate <= @endDate
	) r WHERE r.RowNum = 2
),

 regimen_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY RowNumber DESC) as RowNumber, PatientId,ptn_pk,RegimenType FROM RegimenMapView r 
	) r where r.RowNumber = 1 
 ),

 vitals_cte AS (
	SELECT VitalsId,PatientId,BPDiastolic,BPSystolic,BMI,VisitDate,weight,height FROM (
		SELECT vi.Id as VitalsId, ROW_NUMBER() OVER(PARTITION BY vi.PatientId ORDER BY vi.CreateDate  DESC) as RowNUm, vi.CreateDate as VisitDate, vi.BPDiastolic,vi.BPSystolic,vi.BMI,vi.PatientId,vi.WeightForAge,vi.WeightForHeight,vi.BMIZ,vi.Weight,vi.Height FROM PatientVitals vi INNER JOIN PatientMasterVisit pmv  ON vi.PatientId = pmv.PatientId 
	) v WHERE v.rowNUm =1
 
 ),

patient_artintitiation_dates_cte as (
	SELECT PatientId, CAST(min(ARTDate) AS DATE) as ARTInitiationDate FROM (
		SELECT        PatientId, ARTInitiationDate as ARTDate
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN 
			(SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder o INNER JOIN mst_drug d ON d.drug_pk=o.drug_pk
				WHERE (Prophylaxis = 0 AND d.Abbreviation IS NOT NULL) 				 
				 AND( d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND d.DrugName NOT  LIKE '%Septrin%'  AND d.DrugName  NOT  LIKE '%Dapson%'  )
				 )
		AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL
	) PatientARTdates
	GROUP BY patientId
),

relationship_cte AS (
	SELECT pr.PatientId,pr.PersonId, (CAST(DECRYPTBYKEY(p.FirstName) AS varchar(50)) + ' ' + CAST(DECRYPTBYKEY(p.LastName) AS varchar(50))) as RelationsName,CASE WHEN p.Sex = 51 THEN 'MALE' ELSE 'FEMALE' END as RelationsSex ,CAST(P.DateOfBirth AS DATE) as RelationsDOB, ISNULL(DATEDIFF(YY,P.DateOfBirth,GETDATE()), CASE WHEN l1.DisplayName ='Spouse' THEN 18 WHEN l1.DisplayName ='Child' THEN 14 WHEN l1.DisplayName = 'Sibling' THEN 14 ELSE 18 END ) as RelationsAge,l1.DisplayName as Relationship, ISNULL(ISNULL(CAST(h.TestingDate AS DATE), BaselineDate), '') as RelationsTestingDate, (CASE WHEN h.TestingDate IS NULL THEN l2.DisplayName ELSE  l.DisplayName END) as RelationsTestingResult, pr.CreateDate, h.ReferredToCare FROM 
	PersonRelationship pr
	INNER JOIN Person p ON p.Id = pr.PersonId
	LEFT JOIN HIVTesting h ON h.PersonId = pr.PersonId
	INNER JOIN LookupItem l ON l.Id = h.TestingResult
	INNER JOIN LookupItem l1 ON l1.Id = pr.RelationshipTypeId
	INNER JOIN LookupItem l2 ON l2.Id = BaselineResult
),

all_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY ISNULL(t.RegimenStartDate,t.DispensedByDate) DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,ISNULL(t.RegimenStartDate,t.DispensedByDate) as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL
	) t
),

curr_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY ISNULL(t.RegimenStartDate,t.DispensedByDate) DESC, t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,ISNULL(t.RegimenStartDate,t.DispensedByDate) as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL
	) t WHERE t.rowNum = 1
),

init_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY ISNULL(t.RegimenStartDate,t.DispensedByDate) ASC, t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(ISNULL(t.RegimenStartDate,t.DispensedByDate) AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL --and t.RegimenStartDate IS NOT NULL
	) t WHERE t.rowNum = 1
),

prev_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate FROM (
		SELECT att.RegimenDate, att.PatientId, att.RegimenId, att.Regimen, ROW_NUMBER() OVER(PARTITION BY att.PatientId ORDER BY att.RegimenDate DESC) as RowNum FROM curr_treatmenttracker_cte t 
		INNER JOIN all_treatmenttracker_cte att ON t.PatientId = att.PatientId AND t.RegimenId <> att.RegimenId 
	) t WHERE t.rowNum = 1
),

prev_regimen_date_cte AS (
	SELECT attx.PatientId, MIN(attx.RegimenDate) as Regimendate FROM all_treatmenttracker_cte attx 
		INNER JOIN prev_treatmenttracker_cte pttx ON attx.PatientId = pttx.PatientId AND pttx.RegimenId = attx.RegimenId
	GROUP BY attx.PatientId
),

curr_regimen_date_cte AS (
	SELECT attx.PatientId, MIN(attx.RegimenDate) as Regimendate FROM all_treatmenttracker_cte attx 
		INNER JOIN curr_treatmenttracker_cte pttx ON attx.PatientId = pttx.PatientId AND pttx.RegimenId = attx.RegimenId
	GROUP BY attx.PatientId
),

all_art_cte AS (
	SELECT * FROM (
		SELECT t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL
	) t 
),

--dtg_cte AS (
--	SELECT row * FROM all_art_cte art WHERE art.Regimen LIKE '%DTG%' AND art.RegimenDate BETWEEN @startDate AND @endDate
--),

patientipt_cte_o AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY IptDateCollected DESC) as rowNUm, * FROM PatientIpt i
	) i WHERE i.rowNum = 1
),

patientipt_cte AS (
	SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as rowNum, * FROM (
		SELECT patientId,CreateDate FROM PatientIcf WHERE EverBeenOnIpt = 1 OR OnIpt = 1
		UNION 
		SELECT patientId, CreateDate FROM PatientIptWorkup WHERE StartIpt  = 1
	) ipt 
),

patientipt_cte1 AS (
 SELECT * FROM patientipt_cte WHERE rowNum = 1
),
all_visits_cte AS (
SELECT * FROM (
	SELECT PatientId,VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v WHERE VisitDate IS NOT NULL AND CAST(VisitDate AS DATE) < (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId)
	UNION ALL
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
--	UNION All
--	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientVitals
--	UNION ALL
--	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientAppointment
	) visits WHERE VisitDate < = @endDate
),

last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM all_visits_cte v INNER JOIN mst_User u ON v.lastProvider = u.UserID
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM all_visits_cte v INNER JOIN mst_User u ON v.lastProvider = u.UserID
	) lastVisit WHERE rowNum = 1
),

screening_cte AS (
	SELECT * from (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate DESC) as rowNum, PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
	) ps WHERE ps.rowNum =1
),

cardio_cte AS (
	SELECT PatientId,DisplayName FROM PatientChronicIllness ci INNER JOIN LookupItem li ON ci.ChronicIllness = li.Id WHERE DisplayName like '%Card%'
),

location_cte AS (
	SELECT * FROM (
		SELECT PL.Id, pl.LandMark, PL.PersonId, PL.Location, C.CountyName, SC.Subcountyname, Patient.Id AS PatientId, W.WardName,ROW_NUMBER() OVER (Partition By Patient.Id ORDER BY PL.CreateDate DESC) as RowNum
		FROM            PersonLocation AS PL INNER JOIN
								 County AS C ON PL.County = C.CountyId INNER JOIN
								 County AS SC ON PL.SubCounty = SC.SubcountyId INNER JOIN
								 Patient ON PL.PersonId = Patient.PersonId INNER JOIN
								 County AS W ON PL.Ward = W.WardId
	) r WHERE r.rownum = 1
),

adherence_cte AS (
	SELECT * FROM (
		SELECT PatientId, AdherenceOutcome.Id, AdherenceOutcome.AdherenceType, LookupItem.DisplayName as AdherenceAsessmentOUtcome, LookupMaster.DisplayName AS Adherence, CreateDate,ROW_NUMBER() OVER (Partition By PatientId ORDER BY CreateDate DESC) as RowNum
		FROM            AdherenceOutcome INNER JOIN
								 LookupItem ON AdherenceOutcome.Score = LookupItem.Id INNER JOIN
								 LookupMaster ON AdherenceOutcome.AdherenceType = LookupMaster.Id WHERE AdherenceType = 34
	) r WHERE RowNum =1
),

pregnancy_cte AS (
	SELECT * FROM (
		SELECT PatientID, PregnancyStatus, LMP, EDD, ROW_NUMBER() OVER(PARTITION BY PatientID Order BY LMP DESC) as RowNum FROM (
			SELECT        PI.Id, PI.PatientId, PI.LMP, PI.EDD, PI.CreateDate, LookupItem.Name AS PregnancyStatus
			FROM            PregnancyIndicator AS PI INNER JOIN
									 LookupItem ON PI.PregnancyStatusId = LookupItem.Id
			-- WHERE p.CreateDate < = @endDate		
		) pgs
	) p WHERE RowNum = 1
),

patient_baseline_assessment_cte As (
	Select pba.CD4Count As BaselineCD4, pba.WHOStagename As BaselineWHOStage, pba.PatientId From (
		Select Row_Number() Over (Partition By PatientBaselineAssessment.PatientId Order By PatientBaselineAssessment.CreateDate) As rowNum, PatientBaselineAssessment.PatientId, PatientBaselineAssessment.CreateDate, PatientBaselineAssessment.CD4Count, PatientBaselineAssessment.WHOStage, (Select LookupItem_1.Name From dbo.LookupItem As LookupItem_1 Where LookupItem_1.Id = dbo.PatientBaselineAssessment.WHOStage) As WHOStagename From PatientBaselineAssessment Where (PatientBaselineAssessment.CD4Count Is Not Null) Or (PatientBaselineAssessment.WHOStage Is Not Null)
	) pba Where pba.rowNum = 1
), 

ever_on_tb_tx_cte AS (
	SELECT PatientId, 'Y' as EverBeenOnTBTx FROM (
		SELECT PatientId, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIcf WHERE OnAntiTbDrugs = 1 AND ABS(DATEDIFF(M,CreateDate,@endDate)) <= 12
	) tb WHERE tb.RowNum =1 
),

completed_ipt_cte AS (
	SELECT * FROM (
		SELECT icf.PatientId, CASE WHEN (ipt.IptEvent = 1) THEN 'Completed' ELSE '' END AS IptStatus, iptw.IptStartDate, ipt.CreateDate as DateCompleted, ROW_NUMBER() OVER (PARTITION BY icf.PatientId ORDER BY icf.CreateDate DESC) as RowNum, CASE WHEN EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END as EverBeenOnIPt FROM PatientICF icf 
		LEFT JOIN PatientIptOutcome ipt ON ipt.PatientId = icf.PatientId 
		LEFT JOIN PatientIptWorkup iptw ON iptw.PatientId = icf.PatientId
		-- WHERE EverBeenOnIpt = 1 or ipt.IptEvent = 1
	) ipt WHERE ipt.RowNum = 1 
),

stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By CreateDate Desc) as rowNum,s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, CreateDate as CategorizationDate from PatientCategorization s
		-- WHERE s.CreateDate <= @endDate
	) s WHERE rowNum = 1
),

all_stability_cte AS (
	SELECT * FROM (
		SELECT s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, s.CreateDate as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate <= @endDate and s.CreateDate >=@startDate
	) s
),

dc_cte AS (
	SELECT PatientId, DCModel FROM (
		SELECT        PA.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY PA.CreateDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
	) dc WHERE dc.RowNum = 1
),

all_pia_cte AS (
		select pia.PatientId,pia.VisitDate,pia.PlanningToConceive3M,pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,l1.DisplayName as PartnerHIVStatus,l2.DisplayName as ServiceForEligibleClient,l3.DisplayName as ReasonForFPIneligibility,pia.patientMasterVisitId from PatientPregnancyIntentionAssessment pia 
		LEFT JOIN LookupItem l1  on pia.PartnerHivStatus = l1.Id
		LEFT JOIN LookupItem l2  on pia.ServiceForEligibleClient = l2.Id
		LEFT JOIN LookupItem l3  on pia.ReasonForFPIneligibility = l3.Id
),
last_pia_cte AS (
	select * FROM (
		select ROW_NUMBER() OVER (Partition by PatientId Order By CreateDate Desc) as rowNum, pia.PatientId,pia.VisitDate,pia.PlanningToConceive3M,pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,l1.DisplayName as PartnerHIVStatus,l2.DisplayName as ServiceForEligibleClient,l3.DisplayName as ReasonForFPIneligibility, pia.patientMasterVisitId from PatientPregnancyIntentionAssessment pia 
		LEFT JOIN LookupItem l1  on pia.PartnerHivStatus = l1.Id
		LEFT JOIN LookupItem l2  on pia.ServiceForEligibleClient = l2.Id
		LEFT JOIN LookupItem l3  on pia.ReasonForFPIneligibility = l3.Id
	) lpia WHERE rowNum = 1
),

fp_method_cte AS (
	SELECT      DISTINCT  fp.patientMasterVisitId, fpm.PatientId, l.DisplayName AS FPMethod,fp.VisitDate
	FROM            PatientFamilyPlanning AS fp INNER JOIN
							 PatientFamilyPlanningMethod AS fpm ON fp.Id = fpm.PatientFPId INNER JOIN
							 LookupItem AS l ON fpm.FPMethodId = l.Id
)

--DTG DATA

SELECT * FROM (
	SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,
	CAST(a.DateOfBirth AS DATE) as DOB, a.currentAge,
	a.EnrollmentDate as RegistrationDate,
	a.PhoneNumber,
	a.ContactName,
	a.ContactPhoneNumber,
	art.ARTInitiationDate as ARTStartDate,
	art.Regimen as StartRegimen,
	art_cur.Regimen as CurrentRegimen,
	(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
	as DateOFSwitchToCurrentRegimen,
	CAST(pr.LMP AS DATE) LMP,
	CAST(pr.EDD AS DATE) EDD,
	pr.PregnancyStatus as PregnancyStatusAtLastVisit,
	vl.VlDate as LastVLDate,
	vl.VLResults as LastVL,
	vl2.VlResultsDate as SecondLastVLDate,
	vl2.VLResults as SecondLastVL,
	a.PatientStatus,
	lvst.lastProviderName,
	'' as LastServicePoint,
	NextAppointmentDate
	 FROM all_Patients_cte a 
	LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
	INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
	INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
	INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
	LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
	LEFT JOIN second_last_vl_cte vl2 ON vl2.patientId = a.PatientID
	LEFT JOIN pregnancy_cte pr ON pr.patientId = a.PatientID
	WHERE
	(art_cur.Regimen LIKE '%DTG%')
		OR
	(art.Regimen LIKE '%DTG%')
) dtg

WHERE 
(dtg.ARTStartDate >= @startDate	AND dtg.ARTStartDate <= @endDate) AND dtg.StartRegimen LIKE '%DTG%'
OR
(dtg.DateOFSwitchToCurrentRegimen >= @startDate	AND dtg.DateOFSwitchToCurrentRegimen <= @endDate) AND dtg.CurrentRegimen LIKE '%DTG%'


