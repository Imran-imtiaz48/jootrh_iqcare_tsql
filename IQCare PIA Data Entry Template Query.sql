DECLARE @startDate AS date; 
DECLARE @endDate AS date ;

set @startDate ='2018-09-01';
set @endDate ='2018-10-31';

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

WITH all_Patients_cte as (
SELECT     g.Id as PatientID,g.ptn_pk, g.PersonId, tp.PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, PatientStatus, ExitDate, DateOfBirth, PatientType
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
 ),

 vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr WHERE RowNum = 1 
 ),

 cd4_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as CD4Date, ResultValues  as CD4Results,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 1) AND SAmpleDate <= @endDate
	) cd4 WHERE RowNum = 1 
 ),

 pending_vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId,SampleDate ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Pending')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr -- WHERE RowNum = 1
 ),

all_vl_cte AS (
	SELECT        patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults
	FROM            dbo.PatientLabTracker
	WHERE        (Results = 'Complete')
	AND         (LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
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
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL AND ARTInitiationDate >= 2000
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN 
			(SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder o INNER JOIN mst_drug d ON d.drug_pk=o.drug_pk
				WHERE (Prophylaxis = 0 OR d.Abbreviation IS NOT NULL) 				 
				 AND( d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND d.DrugName NOT  LIKE '%Septrin%'  AND d.DrugName  NOT  LIKE '%Dapson%'  )
				 )
		AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL AND YEAR(o.DispensedByDate) >= 2000 
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

ovc_cte AS (
	SELECT pr.PersonId, (CAST(DECRYPTBYKEY(p.FirstName) AS varchar(50)) + ' ' + CAST(DECRYPTBYKEY(p.LastName) AS varchar(50))) as RelationsName,CASE WHEN p.Sex = 51 THEN 'MALE' ELSE 'FEMALE' END as RelationsSex ,CAST(P.DateOfBirth AS DATE) as RelationsDOB, ISNULL(DATEDIFF(YY,P.DateOfBirth,GETDATE()), 18 ) as RelationsAge,'Guardian' as Relationship,pr.CreateDate FROM 
	PatientOVCStatus pr
	INNER JOIN Person p ON p.Id = pr.GuardianId
),

all_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000
	) t
),

curr_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC, t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000
	) t WHERE t.rowNum = 1
),

init_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC, t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenStartDate) >= 2000 --and t.RegimenStartDate IS NOT NULL
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
		SELECT t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL
	) t 
),

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
		UNION
		SELECT PatientId,Createdate FROM PatientIptOutcome
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
		SELECT PatientId, AdherenceOutcome.Id, AdherenceOutcome.AdherenceType, LookupItem.DisplayName as AdherenceAsessmentOUtcome, LookupMaster.DisplayName AS Adherence, CreateDate, ROW_NUMBER() OVER (Partition By PatientId ORDER BY CreateDate DESC) as RowNum
		FROM            AdherenceOutcome INNER JOIN
								 LookupItem ON AdherenceOutcome.Score = LookupItem.Id INNER JOIN
								 LookupMaster ON AdherenceOutcome.AdherenceType = LookupMaster.Id WHERE AdherenceType = 34
	) r WHERE RowNum =1
),

pregnancy_cte AS (
	SELECT * FROM (
		SELECT PatientID, PregnancyStatus, LMP, EDD,VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientID Order BY LMP DESC) as RowNum,Outcome,DateOfOutcome FROM (
			SELECT        PI.Id, PI.PatientId, PI.LMP, PI.EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.Name AS PregnancyStatus,P.Outcome,P.DateOfOutcome
			FROM            PregnancyIndicator AS PI INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
			LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND P.PatientMasterVisitId = PI.PatientMasterVisitId
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
		SELECT icf.PatientId, ISNULL(li.DisplayName, '') AS IptStatus, iptw.IptStartDate, ipt.CreateDate as DateCompleted, ROW_NUMBER() OVER (PARTITION BY icf.PatientId ORDER BY icf.CreateDate DESC) as RowNum, CASE WHEN EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END as EverBeenOnIPt FROM PatientICF icf 
		LEFT JOIN PatientIptOutcome ipt ON ipt.PatientId = icf.PatientId  LEFT JOIN LookupItem li ON li.Id = ipt.IptEvent
		LEFT JOIN 
			(SELECT PatientId, MIN(IptStartDate) as IptStartDate
			 FROM PatientIptWorkup WHERE IptStartDate IS NOT NULL GROUP BY PatientId) 
			iptw ON iptw.PatientId = icf.PatientId
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
),

high_vl_cte AS (
	SELECT * FROM (
		SELECT  ROW_NUMBER() OVER (Partition by v.PatientId Order By v.VLDate Desc) as rowNum,v.VLDate as LastHighVLDate, v.VLResults as LastHighVL ,v.patientId
		FROM all_vl_cte v 
		WHERE v.VLResults >= 1000 AND (v.VLDate >= @startDate AND v.VLDate <= @endDate )
	) hv WHERE hv.rowNum = 1
),

mch_cte AS (
	SELECT ptn_pk,MCHID FROM mst_patient WHERE MCHID IS NOT NULL
)

/*
--HIGH VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.Regimen as currentRegimen,a.NextAppointmentDate,v.VLDate as LastVLDate, v.VLResults as LastVL,a.PatientStatus,rl.RelationsName,rl.RelationsSex,rl.Relationship,rl.RelationsTestingDate,rl.RelationsTestingResult,rl.ReferredToCare FROM all_Patients_cte a 
LEFT JOIN vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN curr_treatmenttracker_cte r ON a.PatientID = r.PatientId
LEFT JOIN relationship_cte rl ON rl.patientId = a.PatientID
WHERE v.VLResults >= 1000 AND v.VLDate >= @startDate
--WHERE RegimenType IS NOT NULL
*/

/*
--ALL VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,v.VLDate as LastVLDate, v.VLResults as LastVL, sv.VlResultsDate as SecondLastVLDate,sv.VLResults as SecondLastVL, a.PatientStatus FROM all_Patients_cte a 
INNER JOIN vl_cte v ON a.PatientId = v.patientId
LEFT JOIN second_last_vl_cte sv ON sv.patientId = v.patientId 
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
--LEFT JOIN relationship_cte rl ON rl.patientId = a.PatientID
--WHERE v.SampleDate >= '2017-01-01'
--WHERE RegimenType IS NOT NULL
*/
/*
--ALL HIGH VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,v.VLDate as LastVLDate, v.VLResults as LastVL, sv.VlResultsDate as SecondLastVLDate,sv.VLResults as SecondLastVL, a.PatientStatus FROM all_Patients_cte a 
INNER JOIN high_vl_cte v ON a.PatientId = v.patientId
LEFT JOIN second_last_vl_cte sv ON sv.patientId = v.patientId 
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
--LEFT JOIN relationship_cte rl ON rl.patientId = a.PatientID
--WHERE v.SampleDate >= '2017-01-01'
--WHERE RegimenType IS NOT NULL
*/

/*
--PENDING VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,v.VLDate as VLDate, NULL as VL,a.PatientStatus FROM all_Patients_cte a 
INNER JOIN pending_vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
--WHERE v.VLDate >= '2017-01-01'
--WHERE RegimenType IS NOT NULL
*/


/*
--ALL HIGH VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,CAST(v.VLDate AS DATE) as VLDate, v.VLResults as VL, CONCAT(YEAR(v.VLDate),'-',LEFT(CONCAT('0',MONTH(v.VLDate)),2)) as VLPeriod, CONCAT(CAST(v.VLDate AS CHAR(3)),'-',YEAR(v.VLDate)) as VLPeriod2, a.PatientStatus, a.ExitDate FROM all_Patients_cte a 
INNER JOIN vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
WHERE v.VLDate >= @startDate AND v.VLDate <= @endDate
AND v.VLResults >= 1000
ORDER BY v.VLDate DESC
--WHERE RegimenType IS NOT NULL
*/


--select * from vitals_cte --WHERE PatientId = (SELECT id from gcPatientView WHERE EnrollmentNumber='11225-06')
--order by patientId
--7493
--75269
--75269
/*
SELECT * FROM (
SELECT a.EnrollmentNumber as PatientId,a.sex,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,art.ARTInitiationDate as ARTStartDate,vi.BPDiastolic,vi.BPSystolic,vi.VisitDate as VisitDate,a.PatientStatus FROM all_Patients_cte a 
LEFT JOIN vitals_cte vi ON vi.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
--WHERE EnrollmentNumber = '11225-06'
--ORDER BY a.PatientID
) t --WHERE PatientId = '08581-06' 
ORDER BY PatientID
*/

/*
--ADOLESCENTS
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
/*a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,*/
vl.VLDate as VLDate, vl.VLResults as VL,
CASE WHEN a.currentAge >= 0 AND a.currentAge <= 9 THEN 'Age group 0-9' WHEN a.currentAge >= 10 AND a.currentAge <= 14 THEN 'Age group 10-14' WHEN a.currentAge >=15 AND a.currentAge <=19 THEN 'Age group 15-19' ELSE 'Age group 20-24' END as AgeCategory,  
CAST(lvst.lastVisitDate AS DATE) AS LastVisitDate,NextAppointmentDate
,a.PatientStatus,CAST(a.ExitDate AS DATE) as ExitDate 
 FROM all_Patients_cte a 
--LEFT JOIN vitals_cte vi ON vi.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_results_cte vl ON vl.patientId = a.PatientID
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
WHERE a.currentAge BETWEEN 10 and 24
AND PatientStatus = 'Active'
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND PatientStatus = 'Active'
ORDER BY a.PatientID
*/

/*
-- NOT ON IPT
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,
vl.VLDate as VLDate, vl.VLResults as VL,/*ipt.IptDateCollected,CASE WHEN ipt.IptDateCollected IS NULL THEN 'N' ELSE 'Y' END as IptDone,*/
a.PatientStatus,a.ExitDate,lvst.lastVisitDate, NextAppointmentDate
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN patientipt_cte1 ipt ON ipt.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
WHERE --ipt.PatientId IS NULL
ipt.PatientId IS NULL
--AND DATEDIFF (D,a.NextAppointmentDate, GETDATE()) < 90
--AND [EnrollmentDate ] BETWEEN @startDate AND @endDate
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND 
AND (PatientStatus = 'Active') 
ORDER BY a.PatientID
*/

/*
-- ON IPT
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge, CONCAT(l.Location, ' - ', l.WardName, ' - ', l.LandMark)  as PhysicalAddress, vit.weight,
art.ARTInitiationDate as ARTStartDate,ipt.iptStartDate as DateStartedIpt,ipt.DateCompleted as DateCompletedIpt, ipt.EverBeenOnIpt,ipt.IptStatus,
a.[EnrollmentDate ] as RegistrationDate,
vl.VLDate as VLDate, vl.VLResults as VL,
a.PatientStatus,a.ExitDate,lvst.lastVisitDate, NextAppointmentDate
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN completed_ipt_cte ipt ON ipt.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN location_cte l ON l.PatientId = a.PatientID
LEFT JOIN vitals_cte vit ON vit.PatientId = a.PatientID
--WHERE --ipt.PatientId IS NULL
--AND DATEDIFF (D,a.NextAppointmentDate, GETDATE()) < 90
--AND [EnrollmentDate ] BETWEEN @startDate AND @endDate
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND 
--AND (PatientStatus = 'Active') 
ORDER BY a.PatientID
*/


--select * from PatientTreatmentTrackerViewD4T WHERE PatientID = 827
--select * from curr_treatmenttracker_cte WHERE PatientId= 827
--go
-- REGIMEN LINE

/*
-- ALL PATIENTS
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlDate AS DATE) VlResultsDate, vv.VLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, cd4.CD4Results,cd4.CD4Date, a.PatientStatus,a.ExitDate,lv.LastProviderName

/*for stans*/ 
/*SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex as Gender,a.currentAge as Age,a.EnrollmentDate, tt.RegimenLine, tt.Regimen, CASE WHEN Regimen IS NULL THEN NULL ELSE SUBSTRING(Regimen,CHARINDEX('(',Regimen)+1,LEN(Regimen) - CHARINDEX('(',Regimen) - 1) END as LastRegimen 
,a.PatientStatus
,art.ARTInitiationDate
,vv.VlResultsDate,vv.VLResults
,lv.lastVisitDate
,a.NextAppointmentDate
--,rl.RelationsName,rl.RelationsSex,rl.Relationship
*/
--SELECT DISTINCT RegimenType as Regimen
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN second_last_vl_cte svv ON svv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN cd4_results_cte cd4 ON cd4.patientId = a.PatientID
--LEFT JOIN relationship_cte rl ON rl.PatientId = a.PatientID AND rl.Relationship NOT IN ('Child', 'Sibling')
--LEFT JOIN regimen_cte r ON r.patientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
--AND (DATEDIFF (D,a.NextAppointmentDate, @startDate) >= 90 OR a.NextAppointmentDate IS NULL)
--AND (DATEDIFF (D,a.EnrollmentDate, @startDate) <= 90 OR DATEDIFF (D,lv.lastVisitDate, @startDate) <= 90)

--WHERE Regimen IS NOT NULL AND RegimenType IS NULL
--AND PatientStatus = 'Death' 
--AND PatientStatus ='Transfer Out'
--AND (a.ExitDate < @startDate)
--AND Regimen = 'Unknown'
--WHERE PatientStatus = 'Transfer Out' --AND PatientStatus !='Transfer Out'  --AND Regimen = 'Unknown'
--WHERE PatientStatus != 'DEATH' AND PatientStatus !='Transfer Out'
--WHERE PatientStatus = 'DEATH' AND ExitDate < @startDate
--WHERE DATEDIFF (Y,a.NextAppointmentDate, @endDate) <= 90
--AND a.currentAge <= 9
--AND a.[EnrollmentDate] <=@endDate
--AND lv.lastVisitDate >='2018-06-01'
--AND a.PatientStatus = 'Transfer Out' 
--AND (a.ExitDate IS NULL OR a.ExitDate <= @endDate)
--AND PatientStatus !='Transfer Out'  /*AND Regimen <> 'Unknown'*/ AND (a.ExitDate IS NULL OR a.ExitDate >='2018-05-01')
--AND Regimen LIKE '%third%'
-- and a.EnrollmentNumber = '13939-21354'
*/
/*
--HIGH BP - Hypertension
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,tt.Regimen ,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate,CAST(art.ARTInitiationDate AS DATE) as ARTStartDate,/* CAST(fv.firstVisitDate AS DATE) firstVisitDate,*/ CAST(vit.VisitDate AS DATE) VisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlResultsDate AS DATE) VlResultsDate, vv.VLResults, CONCAT(vit.BPSystolic, '/', vit.BPDiastolic)/*, a.PatientStatus*/
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN vitals_cte vit ON vit.PatientId = a.PatientID
-- WHERE vit.BPSystolic <= 140 AND (BPSystolic > 0 AND BPDiastolic > 0)
INNER JOIN cardio_cte cd ON cd.PatientId = a.PatientID 
*/

/*
-- Adherence and location
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, '' as RegistrationAge,a.currentAge,tt.Regimen ,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate,CAST(art.ARTInitiationDate AS DATE) as ARTStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlResultsDate AS DATE) VlResultsDate, vv.VLResults/*, a.PatientStatus*/
,l.CountyName,l.Subcountyname,l.WardName,l.Location, ad.AdherenceAsessmentOUtcome
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN location_cte l ON l.PatientId = a.PatientID
LEFT JOIN adherence_cte ad ON ad.PatientId = a.PatientID
WHERE PatientStatus <> 'Death' and PatientStatus <> 'Transfer Out'
*/

/*
-- UNDOCUMENTED LOST
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,
vl.VLDate as VLDate, vl.VLResults as VL,
a.PatientStatus,
NextAppointmentDate,
'' as Comments
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
WHERE 
DATEDIFF (D,a.NextAppointmentDate, GETDATE()) >= 90
--AND [EnrollmentDate ] BETWEEN @startDate AND @endDate
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND 
AND (PatientStatus = 'Active') 
ORDER BY a.PatientID
*/

/*
-- New ART Initiations
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,
--,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.EnrollmentDate as RegistrationDate,
it.ARTInitiationDate as ARTStartDate,
it.Regimen as StartRegimen,
tt.Regimen as CurrentRegimen,
vl.VlDate as VLDate, vl.VLResults as VL,
a.PatientStatus,
NextAppointmentDate,
'' as Comments
-- ,a.PatientType
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
-- LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte it ON it.PatientId = a.PatientID
WHERE it.ARTInitiationDate <= @endDate AND it.ARTInitiationDate >= @startDate and a.PatientType = 258 -- New
--AND ABS(DATEDIFF(M,a.EnrollmentDate,@startDate)) < 3
ORDER BY a.PatientID
*/

-- select * from LookupItem WHERE id in (258,257)

/*
-- Enrolled and not initiated
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,
--,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,
vl.VLDate as VLDate, vl.VLResults as VL,
a.PatientStatus,a.ExitDate,
NextAppointmentDate,
'' as Comments
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
WHERE 
EnrollmentDate  <= @endDate AND EnrollmentDate  >= @startDate
AND art.ARTInitiationDate IS NULL
ORDER BY a.PatientID
*/

/*
--DTG DATA
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,
a.Sex,CAST(a.DateOfBirth AS DATE) as DOB, a.currentAge,
a.EnrollmentDate as RegistrationDate,
a.PhoneNumber,
a.ContactName,
a.ContactPhoneNumber,
art.ARTInitiationDate as ARTStartDate,
art.Regimen as StartRegimen,
art_cur.Regimen as CurrentRegimen,
(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
as DateOFSwitchToCurrentRegimen,
art_prev.Regimen,
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
LEFT JOIN prev_treatmenttracker_cte art_prev ON art_prev.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN second_last_vl_cte vl2 ON vl2.patientId = a.PatientID
LEFT JOIN pregnancy_cte pr ON pr.patientId = a.PatientID
WHERE 
EnrollmentDate  <= @endDate AND EnrollmentDate  >= @startDate
AND art_cur.Regimen LIKE '%DTG%'
-- AND a.CurrentAge BETWEEN 18 AND 49
ORDER BY a.PatientID
*/


/*
--DC MAPPING EXTRCATION
SELECT a.EnrollmentNumber as PatientId,a.sex,CAST(a.DateOfBirth AS DATE) as DOB,
a.EnrollmentDate as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,
bl.BaselineWHOStage,
bl.BaselineCD4,
art.Regimen,
art_cur.Regimen as CurrentRegimen,
(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
as DateOFSwitchToCurrentRegimen,
ISNULL(tb.EverBeenOnTBTx,'N') as EverBeenOnTBTx,
ISNULL(ipt.Completed, 'N') as CompletedIPT,
adh.AdherenceAsessmentOUtcome,
vit.BMI,
vl.VLResults as LastVL,
vl.VLDate as LastVLDate,
pg.PregnancyStatus as PregnancyAtLastVisit,
'' AS Service,
st.Categorization,
CASE WHEN st.Categorization = 'Stable' THEN dc.DCModel ELSE '' END AS StableModel,
CAST(lvst.lastVisitDate AS DATE) AS lastVisitDate,
NextAppointmentDate,
a.PatientStatus,
a.ExitDate,
lvst.lastProviderName
 FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN ever_on_tb_tx_cte tb ON tb.patientId = a.PatientID
LEFT JOIN patient_baseline_assessment_cte bl ON bl.patientId = a.PatientID
LEFT JOIN completed_ipt_cte ipt ON ipt.patientId = a.PatientID
LEFT JOIN adherence_cte adh ON adh.patientId = a.PatientID
LEFT JOIN vitals_cte vit ON vit.patientId = a.PatientID
LEFT JOIN pregnancy_cte pg ON pg.patientId = a.PatientID
LEFT JOIN stability_cte st on st.PatientId = a.PatientID
LEFT JOIN dc_cte dc on dc.PatientId = a.PatientID

WHERE 
EnrollmentDate  <= @endDate AND EnrollmentDate  >= @startDate
ORDER BY a.PatientID

*/
/*
-- PIA CTE
SELECT 
	a.PatientId,
	a.PatientName,
	a.Sex,
	a.CUrrentAge,
	tt.Regimen,
	a.[EnrollmentDate] as RegistrationDate,
	art.ARTInitiationDate,
--	vst.lastVisitdate,
	a.NextAppointmentDate,
	CAST(pia.visitDate AS DATE) as VisitDate,
	fpm.fpmethod,
	pia.PlanningToConceive3M,
	pia.RegularMenses,
	pia.ClientEligibleForFP,
	pia.PartnerHIVStatus,
	pia.ServiceForEligibleClient,
	pia.ReasonForFPIneligibility
 FROM all_Patients_cte a 
	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
	LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
	LEFT JOIN fp_method_cte fpm ON a.PatientId=fpm.PatientId 
	INNER JOIN last_pia_cte pia ON fpm.PatientMasterVisitId = pia.PatientMasterVisitId
 WHERE ABS(DATEDIFF(M,pia.VisitDate,getdate())) <= 2

 */

/* 
-- ALL PATIENTS
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, a.ContactName, a.ContactPhoneNumber,/* rl.RelationsName,rl.RelationsSex,rl.RelationsAge, rl.Relationship, rl.ReferredToCare,*/ ovc.RelationsName,ovc.RelationsSex,ovc.Relationship, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlDate AS DATE) VlResultsDate, vv.VLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, a.PatientStatus,lv.LastProviderName
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN second_last_vl_cte svv ON svv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
--LEFT JOIN relationship_cte rl ON rl.PatientId = a.PatientID AND rl.Relationship NOT IN ('Child', 'Sibling')
LEFT JOIN ovc_cte ovc ON ovc.PersonId = a.PersonId
WHERE EnrollmentDate <= @endDate AND (a.currentAge >= 1 AND a.currentAge <=9)
*/

/*
--HIGH VL
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, hvl.LastHighVLDate,hvl.LastHighVL,CAST(vv.VlDate AS DATE) LastVlResultsDate, vv.VLResults as LastVLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,  a.PatientStatus,lv.LastProviderName
FROM all_Patients_cte a 
INNER JOIN high_vl_cte hvl ON hvl.PatientId = a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN second_last_vl_cte svv ON svv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
*/

/*
--PREGNANT
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, P.PregnancyStatus,P.EDD, CAST(vv.VlDate AS DATE) LastVlResultsDate, vv.VLResults as LastVLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,  a.PatientStatus,lv.LastProviderName
FROM all_Patients_cte a 
INNER JOIN pregnancy_cte P ON P.PatientId = a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN second_last_vl_cte svv ON svv.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
-- WHERE P.PregnancyStatus = 'PG'
*/
/*

--Wrongly mapped Patient Type
SELECT a.PatientID as Id, a.PatientName,a.EnrollmentNumber,a.EnrollmentDate, pID.IdentifierValue as PatientIdentifier, L.DisplayName as PatientType, PEN.PatientId, PEN.EnrollmentDate,PEN.CreateDate, CONCAT(MU.UserFirstName,' ', MU.UserLastName) as CreatingUser,PEN.CreatedBy
FROM all_Patients_cte a
INNER JOIN PatientEnrollment PEN  ON a.PatientId = PEN.PatientId
INNER JOIN mst_User MU ON PEN.CreatedBy = MU.UserID 
INNER JOIN PatientIdentifier PID ON PID.PatientId = PEN.PatientId
INNER JOIN Patient P ON P.Id = PEN.PatientId
INNER JOIN LookupItem L ON L.Id = P.PatientType
WHERE 
	pid.IdentifierValue NOT LIKE '13939%' 
	AND pid.IdentifierTypeId = 1
	AND L.DisplayName = 'New' 
	AND  ServiceAreaId = 1
	AND PEN.CreateDate	 > = '20170901'
	AND PEN.CreatedBy <> 114
	AND P.DeleteFlag = 0
	AND A.PatientStatus = 'ACTIVE'
ORDER BY
	PEN.CreatedBy
*/

-- MCH PATIENTS
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,mch.MCHID as [MCH Number],a.PatientName,a.Sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType,CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate,
pia.VisitDate, pia.PlanningToConceive3M, pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,pia.PartnerHIVStatus,Pia.ServiceForEligibleClient,pia.ReasonForFPIneligibility,
CAST(ittx.ARTInitiationDate AS DATE) as ARTStartDate, a.PatientStatus,a.ExitDate,lv.LastProviderName
FROM all_Patients_cte a 
INNER JOIN mch_cte mch ON mch.Ptn_Pk = a.ptn_pk
LEFT JOIN  last_pia_cte pia ON pia.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
