-- Known Positives, pregnant, pmtct

-- Date Enrolled in care --Date Enrolled in MCH --**
-- demographics
-- All visits*
-- PregnancyScreening*
-- PregancyIntention*
-- FamilyPlanning Method*
-- Pregnancy Outcome*
-- LastVL*
-- SecondLastVL*
-- Regimen*
-- Adherence Assessment*
-- Stability Assessment*

DECLARE @startDate AS date; 
DECLARE @endDate AS date ;

set @startDate ='2017-01-01';
set @endDate ='2018-09-30';

WITH all_Patients_cte as (
	SELECT     g.Id as PatientID, g.PersonId, tp.PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, PatientStatus, ExitDate, DateOfBirth, PatientType
	FROM            gcPatientView2 g
	LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster]) tp ON tp.PatientPK = g.ptn_pk
	WHERE g.Sex = 52  --AND Id = 9694
),

patient_baseline_assessment_cte As (
	Select pba.CD4Count As BaselineCD4, pba.WHOStagename As BaselineWHOStage, pba.PatientId From (
		Select Row_Number() Over (Partition By PatientBaselineAssessment.PatientId Order By PatientBaselineAssessment.CreateDate) As rowNum, PatientBaselineAssessment.PatientId, PatientBaselineAssessment.CreateDate, PatientBaselineAssessment.CD4Count, PatientBaselineAssessment.WHOStage, (Select LookupItem_1.Name From dbo.LookupItem As LookupItem_1 Where LookupItem_1.Id = dbo.PatientBaselineAssessment.WHOStage) As WHOStagename From PatientBaselineAssessment Where (PatientBaselineAssessment.CD4Count Is Not Null) Or (PatientBaselineAssessment.WHOStage Is Not Null)
	) pba Where pba.rowNum = 1
), 

all_visits_cte AS (
		SELECT * FROM (
			SELECT PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId FROM PatientMasterVisit v 
				WHERE VisitDate IS NOT NULL AND CAST(VisitDate AS DATE) < (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId)
				AND ABS(DATEDIFF(D,Start,VisitDate)) < 30
			UNION
			SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId FROM PatientScreening  
		) visits 
		WHERE VisitDate <= @endDate and VisitDate >= @startDate
),

all_vitals_cte AS (
	SELECT VitalsId,PatientMasterVisitId,PatientId,BPDiastolic,BPSystolic,BMI,VisitDate,weight,height FROM (
		SELECT vi.Id as VitalsId,PatientMasterVisitId, ROW_NUMBER() OVER(PARTITION BY vi.PatientMasterVisitId ORDER BY vi.CreateDate  DESC) as RowNUm, vi.CreateDate as VisitDate, vi.BPDiastolic,vi.BPSystolic,vi.BMI,vi.PatientId,vi.WeightForAge,vi.WeightForHeight,vi.BMIZ,vi.Weight,vi.Height FROM PatientVitals vi INNER JOIN PatientMasterVisit pmv  ON vi.PatientId = pmv.PatientId 
	) v WHERE v.RowNUm = 1
),

last_vl_cte AS (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
											FROM            dbo.PatientLabTracker
											WHERE        (Results = 'Complete')
											AND         (LabTestId = 3) AND SampleDate <= @endDate --	AND SampleDate <= '2018-05-15'
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

init_treatmenttracker_cte AS (
	SELECT * FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC, t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenStartDate) >= 2000 --and t.RegimenStartDate IS NOT NULL
	) t WHERE t.rowNum = 1
),

all_adherence_cte AS (
	SELECT * FROM (
		SELECT PatientId, AdherenceOutcome.Id,PatientMasterVisitId, AdherenceOutcome.AdherenceType, LookupItem.DisplayName as AdherenceAsessmentOUtcome, LookupMaster.DisplayName AS Adherence, CreateDate, ROW_NUMBER() OVER (Partition By PatientId ORDER BY CreateDate DESC) as RowNum
		FROM            AdherenceOutcome INNER JOIN
								 LookupItem ON AdherenceOutcome.Score = LookupItem.Id INNER JOIN
								 LookupMaster ON AdherenceOutcome.AdherenceType = LookupMaster.Id WHERE AdherenceType = 34
	) r  
),

all_pregnancy_cte AS (
	SELECT * FROM (
		SELECT PatientID, PatientMasterVisitId, PregnancyStatus, LMP, EDD,VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientMasterVisitId Order BY LMP DESC) as RowNum,Outcome,DateOfOutcome FROM (
			SELECT        PI.Id, PI.PatientId, PI.PatientMasterVisitId, PI.LMP, PI.EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.Name AS PregnancyStatus,P.Outcome,P.DateOfOutcome
			FROM            PregnancyIndicator AS PI INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
			LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND P.PatientMasterVisitId = PI.PatientMasterVisitId
		) pgs
	) p WHERE p.RowNum = 1
),

all_pia_cte AS (
	SELECT * FROM (
		select ROW_NUMBER() OVER(PARTITION BY PatientMasterVisitId Order BY pia.Id DESC) as RowNum, pia.PatientId,pia.VisitDate,pia.PlanningToConceive3M,pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,l1.DisplayName as PartnerHIVStatus,l2.DisplayName as ServiceForEligibleClient,l3.DisplayName as ReasonForFPIneligibility,pia.patientMasterVisitId from PatientPregnancyIntentionAssessment pia 
		LEFT JOIN LookupItem l1  on pia.PartnerHivStatus = l1.Id
		LEFT JOIN LookupItem l2  on pia.ServiceForEligibleClient = l2.Id
		LEFT JOIN LookupItem l3  on pia.ReasonForFPIneligibility = l3.Id
	) p WHERE p.RowNum = 1
),

fp_method_cte AS (
	SELECT      DISTINCT fp.patientMasterVisitId, fpm.PatientId, l.DisplayName AS FPMethod,fp.VisitDate
	FROM            PatientFamilyPlanning AS fp INNER JOIN
							 PatientFamilyPlanningMethod AS fpm ON fp.Id = fpm.PatientFPId INNER JOIN
							 LookupItem AS l ON fpm.FPMethodId = l.Id
	WHERE fp.VisitDate <= @endDate and fp.VisitDate >= @startDate
),

all_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientMasterVisitId ORDER BY Id) AS rowNum, s.PatientId, PatientMasterVisitId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, s.CreateDate as CategorizationDate from PatientCategorization s
	) s WHERE rowNum = 1
),

mch_cte AS (
	select PatientId,MCHNumber, CAST(StartDate AS DATE) as MCHEnrollmentDate FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber, lp.StartDate 
		FROM mst_Patient M 
			INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk 
			INNER JOIN lnk_patientprogramstart lp ON lp.ptn_pk = p.ptn_pk
			INNER JOIN  mst_module mm  ON lp.ModuleId = mm.ModuleID 
		WHERE ModuleName = 'MCH' AND MCHID IS NOT NULL -- AND (CAST(lp.StartDate AS DATE) >= '2017-01-01' AND CAST(lp.StartDate AS DATE) <= '2017-12-31')
		AND (CAST(lp.StartDate AS DATE) >= @startDate AND CAST(lp.StartDate AS DATE) <= @endDate)
	) ti WHERE rowNUm = 1
)

SELECT 
	a.PatientID, a.DateOfBirth, a.Sex, a.EnrollmentDate,
	mch.MCHEnrollmentDate,
	pba.BaselineCD4, pba.BaselineWHOStage,
	vis.VisitDate, /*vis.PatientMasterVisitId,*/ vit.Height, vit.Weight, vit.BMI,
	CASE WHEN vit.BPSystolic IS NULL OR vit.BPDiastolic IS NULL THEN '' ELSE CONCAT(vit.BPSystolic,'/',vit.BPDiastolic) END as BP,
	lvl.VlDate as LastVLDate, lvl.VLResults as LastVLResults, svl.VlResultsDate as SecondLastVLDate, svl.VLResults as SecondLastVLResults,
	ireg.ARTInitiationDate,ireg.Regimen as StartRegimen,
	adh.AdherenceAsessmentOutcome,
	apg.PregnancyStatus as PregnancyStatusAtVisit, -- apg.Outcome as PregnancyOutcome, apg.DateOfOutcome as DateOfPregnancyOutcome ,
	pia.PlanningToConceive3M,
	FpMethod = STUFF((
          SELECT ',' + fp.FpMethod
          FROM fp_method_cte fp
          WHERE fp.PatientMasterVisitId = vis.PatientMasterVisitId
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
	ast.Categorization as StablityStatus,
	a.PatientStatus,
	a.ExitDate
FROM all_Patients_cte a 
LEFT JOIN patient_baseline_assessment_cte pba ON pba.PatientId = a.PatientID
INNER JOIN all_visits_cte vis ON vis.PatientId = a.PatientID 
LEFT JOIN all_vitals_cte vit ON vis.PatientMasterVisitId = vit.PatientMasterVisitId
LEFT JOIN last_vl_cte lvl ON lvl.patientId = a.PatientId
LEFT JOIN second_last_vl_cte svl ON svl.patientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ireg ON ireg.PatientId = a.PatientID
LEFT JOIN all_adherence_cte adh ON adh.PatientMasterVisitId = vis.PatientMasterVisitId
LEFT JOIN all_pregnancy_cte apg ON apg.PatientMasterVisitId = vis.PatientMasterVisitId
LEFT JOIN all_pia_cte pia ON pia.PatientMasterVisitId = vis.PatientMasterVisitId
LEFT JOIN all_stability_cte ast ON ast.PatientMasterVisitId = vis.PatientMasterVisitId
INNER JOIN mch_cte mch ON mch.PatientID = a.PatientID
ORDER BY PatientId

