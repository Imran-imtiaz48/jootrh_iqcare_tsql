DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2018-06-06';
set @endDate = '2019-04-16';
-- SET @endDate = DATEADD(D,-1,DATEADD(M,3,@startDate))

set @midDate = '2018-06-30'; -- used when comparing the effectiveness of Viremia clinic - pre and post

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,UPPER(tp.ContactName) AS ContactName, EnrollmentNumber, UPPER(CONCAT(g.FirstName, ' ', REPLACE(g.MiddleName, char(0),'') , ' ', g.LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, MaritalStatus, EducationLevel,ce.ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
--INNER JOIN PatientContact
 LEFT JOIN (
	SELECT PatientId,ExitReason,ExitDate,TransferOutfacility,CreatedBy FROM (
		SELECT PatientId,l.Name AS ExitReason,ExitDate,TransferOutfacility,CreatedBy,ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM patientcareending ce INNER JOIN LookupItem l ON
		l.Id = ce.ExitReason
		WHERE ce.DeleteFlag = 0 AND ce.ExitDate < @startDate
	) ce WHERE rowNum = 1
 ) ce ON g.Id = ce.PatientId
LEFT JOIN (
	SELECT PersonId, MobileNumber, AlternativeNumber,EmailAddress FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PersonId ORDER BY CreateDate) as RowNum, PC.PersonId, PC.MobileNumber, PC.AlternativeNumber,PC.EmailAddress FROM PersonContactView PC
	) pc1 WHERE pc1.RowNum = 1
) PC ON PC.PersonId = g.PersonId	
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
LEFT JOIN (
		SELECT PatientId,
		CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
	 -- WHERE CreateDate <= @endDate 
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

 baseline_cd4_results_cte AS (
	SELECT * FROM (
		SELECT *,ROW_NUMBER() OVER (Partition By PatientId ORDER BY CD4Date ASC) as RowNum FROM (
			SELECT        patientId,SampleDate as CD4Date, ResultValues  as CD4Results
			FROM            dbo.PatientLabTracker
			WHERE        (Results = 'Complete')
			AND         (LabTestId = 1) AND SAmpleDate <= @endDate
			UNION 
			SELECT patientId,CreateDate,CD4Count from PatientBaselineAssessment WHERE CD4Count > 0
		) cd4
	) cd4 WHERE RowNum = 1 
 ),

 cd4_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as CD4Date, ResultValues  as CD4Results,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 1) AND SAmpleDate <= @endDate
	) cd4 WHERE RowNum = 1 
 ),

  all_vl_cte AS (
	SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as VlDate, CASE WHEN tr.Undetectable = 1  OR ResultTexts LIKE '%< LDL%' then 0 else ResultValues END  as VLResults
	FROM            dbo.PatientLabTracker t
	INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
	WHERE        (Results = 'Complete')
	AND         (t.LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
 ),

  all_vl_sample_cte AS (
	SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as VlSampleDate, CASE WHEN tr.Undetectable = 1  OR ResultTexts LIKE '%< LDL%' then 0 else ResultValues END  as VLResults
	FROM            dbo.PatientLabTracker t
	INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
	WHERE        (t.LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
 ),

 last_vl_sample_cte AS (
	SELECT PatientId, VlSampleDate, VLResults FROM (
		SELECT        patientId, VlSampleDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY VlSampleDate DESC) as RowNum
											FROM            all_vl_sample_cte
	) r WHERE r.RowNum = 1
 ),

 pending_vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Pending')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr -- WHERE RowNum = 1
 ),

 last_vl_sample_in_past_1yr_cte AS (
	SELECT PatientId,SampleDate,VLResults FROM (
		SELECT        patientId,CAST (SampleDate AS DATE) as SampleDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE   
		         (LabTestId = 3) AND SampleDate <= @endDate AND DATEDIFF(MM,SampleDate, @endDate) <= 12 
	) vlr WHERE RowNum = 1
 ),

  last_vl_result_in_past_1yr_cte AS (
	SELECT PatientId,VlDate,VLResults FROM (
		SELECT        patientId, VlDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY vldate DESC) as RowNum
		FROM            all_vl_cte
		WHERE       VlDate <= @endDate AND DATEDIFF(MM,VlDate, @endDate) <= 12
	) vlr WHERE RowNum = 1
 ),


 pre_viremia_vl_cte AS (
	SELECT * FROM (
		SELECT  ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY vlDate DESC) rowNum, * FROM all_vl_cte WHERE VlDate < @midDate AND Vldate > DATEADD(YYYY,-1,@midDate)
	) vl WHERE vl.rowNum <= 2	
 ),

 post_viremia_vl_cte AS (
	SELECT * FROM (
		SELECT  ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY vlDate ASC) rowNum, * FROM all_vl_cte WHERE VlDate >= @midDate
	) vl WHERE vl.rowNum <= 2
 ),

 pre_viremia_vl_1_cte AS (
 	SELECT * FROM (
 		SELECT  ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY vlDate DESC) rowNum, * FROM all_vl_cte WHERE VlDate < @midDate AND VLResults >= 1000 AND Vldate > DATEADD(YYYY,-1,@midDate)
 	) vl WHERE vl.rowNum = 1 
 ),

 post_viremia_vl_1_cte AS (
 	SELECT * FROM (
 		SELECT  ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY vlDate ASC) rowNum, * FROM all_vl_cte WHERE VlDate >= @midDate
 	) vl WHERE vl.rowNum = 1 
 ),

-- VIREMIA CLINIC - Before and after Viremia clinia re-suppression comparisons
resuppression_cte AS (
	SELECT -- Scenario 1: Both First High VL and Second VL before mid period (ONSET of Viremia clinic)
	 pre_vm1.patientId, pre_vm1.VlDate as FirstVlDate, pre_vm1.VLResults as FirstVLResult, pre_vm2.VlDate as SecondVLDate,pre_vm2.VLResults as SecondVLResult, 'PreViremiaClinic' as Scenario
	FROM 
	(SELECT * FROM pre_viremia_vl_cte WHERE rowNum = 2 AND VLResults >= 1000) pre_vm1
	INNER JOIN (SELECT * FROM pre_viremia_vl_cte WHERE rowNum = 1) pre_vm2 ON pre_vm1.PatientId = pre_vm2.PatientId
		UNION
	SELECT  -- Scenario 2: Both First High VL and Second VL after mid period (ONSET OF Viremia clinic)
	 post_vm1.patientId, post_vm1.VlDate as FirstVlDate, post_vm1.VLResults as FirstVLResult, post_vm2.VlDate as SecondVLDate,post_vm2.VLResults as SecondVLResult, 'PostViremiaClinic' as scenario
	FROM 
	(SELECT * FROM post_viremia_vl_cte WHERE rowNum = 1 AND VLResults >= 1000) post_vm1
	INNER JOIN (SELECT * FROM post_viremia_vl_cte WHERE rowNum = 2) post_vm2 ON post_vm1.PatientId = post_vm2.PatientId
		UNION
	SELECT -- Scenario 3: First High VL before mid period and Second VL after mid period
	 pre_vm.patientId, pre_vm.VlDate as FirstVlDate, pre_vm.VLResults as FirstVLResult, post_vm.VlDate as SecondVLDate,post_vm.VLResults as SecondVLResult, 'PreAndPostViremiaClinic' as scenario
	FROM pre_viremia_vl_1_cte pre_vm 
	INNER JOIN post_viremia_vl_1_cte post_vm ON pre_vm.PatientId = post_vm.PatientId
),

 baseline_vl_cte AS (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate ASC) as RowNum
											FROM            dbo.PatientLabTracker
											WHERE        (Results = 'Complete')
											AND         (LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
	) r WHERE r.RowNum = 1
 ),	

 vl_cte AS (
	SELECT PatientId, VlDate, VLResults FROM (
		SELECT        patientId, VlDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY VLDate DESC) as RowNum
											FROM            all_vl_cte
	) r WHERE r.RowNum = 1
 ),

 second_last_vl_cte as (
	SELECT * FROM (
		SELECT        patientId,VlDate as VlResultsDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY VLDate DESC) as RowNum
											FROM            all_vl_cte
	) r WHERE r.RowNum = 2
 ),

 regimen_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY RowNumber DESC) as RowNumber, PatientId,ptn_pk,RegimenType FROM RegimenMapView r 
	) r where r.RowNumber = 1 
 ),

 all_vitals_cte AS (
	SELECT PatientId, PatientMasterVisitId,Weight,Height,VisitDate,BMI,BPDiastolic,BPSystolic FROM ( 
		SELECT ROW_NUMBER() OVER(PARTITION BY pmv.PatientId, CAST (vi.CreateDate AS DATE) ORDER BY vi.VisitDate) as RowNum,pmv.Id as PatientMasterVisitId, vi.Id as VitalsId, CAST (vi.CreateDate AS DATE) as VisitDate, vi.BPDiastolic,vi.BPSystolic,vi.BMI,vi.PatientId,vi.WeightForAge,vi.WeightForHeight,vi.BMIZ,vi.Weight,vi.Height FROM PatientVitals vi INNER JOIN PatientMasterVisit pmv  ON vi.PatientId = pmv.PatientId  
	) vit WHERE rowNUm = 1
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
				WHERE (Prophylaxis = 0 AND d.Abbreviation IS NOT NULL) 				 
				 AND( d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND d.DrugName NOT  LIKE '%Septrin%'  AND d.DrugName  NOT  LIKE '%Dapson%'  )
				 )
		AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL AND YEAR(o.DispensedByDate) >= 2000  AND o.DispensedByDate <= @endDate
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
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t
),

curr_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine, TLE400 FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC,t.PatientMasterVisitId DESC, t.id DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
		TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
				INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
				 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
				)
		 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate

	) t WHERE t.rowNum = 1
),

init_treatmenttracker_cte AS (
	SELECT TLE400,PatientMasterVisitId, PatientId,Regimen,RegimenId, t.ARTInitiationDate, Line as regimenLine FROM (
		SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC, t.RegimenStartDate ASC,PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line ,
		TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
				INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
				 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
				)		
		FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate --and t.RegimenStartDate IS NOT NULL
	) t WHERE t.rowNum = 1
),

prev_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT att.RegimenDate, att.PatientId, att.RegimenId, att.Regimen,  CASE WHEN att.RegimenLine LIKE '%First%' THEN '1' WHEN att.RegimenLine LIKE '%Second%' THEN '2' WHEN att.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line, ROW_NUMBER() OVER(PARTITION BY att.PatientId ORDER BY att.RegimenDate DESC) as RowNum FROM curr_treatmenttracker_cte t 
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

patientIptInitiations AS (
SELECT * FROM (
	select PatientId,PatientMasterVisitId,CAST(IptStartDate AS DATE) AS IPTStart,CreatedBy as IPTStartedBy, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY IptStartDate ASC) as RowNum FROM  PatientIptWorkup WHERE StartIpt  = 1 
	AND IptStartDate BETWEEN @startDate AND @endDate
) ipt WHERE rowNUm = 1	--- order by createdate desc
),

ipt_status_cte AS (
	SELECT 
		PatientId, EverBeenOnIpt,IptStartDate,Completed,OnIpt,Discontinued,ReasonForDiscontinuation,rfd,CodedRFD
	FROM (
		SELECT 
			icf.PatientId
			,CASE WHEN iptOutcome.IptEvent IS NOT NULL THEN 'Y' ELSE CASE WHEN iptStart.IptStartDate IS NOT NULL THEN 'Y' ELSE CASE WHEN icf.EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END END END as EverBeenOnIpt, l1.Name
			,CAST(iptStart.IptStartDate AS  DATE) AS IptStartDate
			,CASE WHEN l1.Name = 'Completed' THEN 'Y' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) >=6 AND l1.Name IS NULL THEN 'Y'  ELSE 'N' END END AS Completed
			,CASE WHEN l1.Name IS NOT NULL THEN 'N' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) <6 THEN 'Y'  ELSE 'N' END END AS OnIpt
			,CASE WHEN l1.Name = 'Discontinued' THEN 'Y' ELSE 'N' END AS Discontinued 
			,CASE WHEN l1.Name = 'Discontinued' THEN 
				CASE WHEN l2.Name IS NOT NULL THEN l2.Name 
				ELSE 
					CASE WHEN iptOutcome.ReasonForDiscontinuation LIKE '%rashes%' OR iptOutcome.ReasonForDiscontinuation LIKE '%ar%' OR iptOutcome.ReasonForDiscontinuation LIKE '%adverse%' OR iptOutcome.ReasonForDiscontinuation LIKE '%peripheral%' OR iptOutcome.ReasonForDiscontinuation LIKE '%adh%' OR iptOutcome.ReasonForDiscontinuation LIKE '%pn%'  OR iptOutcome.ReasonForDiscontinuation LIKE '%oedema%' OR iptOutcome.ReasonForDiscontinuation LIKE '%vl%' OR iptOutcome.ReasonForDiscontinuation LIKE '%numb%' OR iptOutcome.ReasonForDiscontinuation LIKE '%toxi%' OR iptOutcome.ReasonForDiscontinuation LIKE '%a/e%' OR iptOutcome.ReasonForDiscontinuation LIKE '%rash%'           THEN 'Toxicity' ELSE  CASE WHEN iptOutcome.ReasonForDiscontinuation LIKE '%TB%' THEN 'TB' ELSE 'Stopped' END 
					END 
				END 
			ELSE NULL END AS ReasonForDiscontinuation
			,ReasonForDiscontinuation as RFD
			,l2.Name as CodedRFD
		FROM 
			(
				SELECT PatientId,MAX(CAST(EverBeenOnIpt AS INT)) AS EverBeenOnIpt FROM PatientIcf GROUP BY PatientId  
			) icf 
		LEFT JOIN 
			(
				SELECT PatientId, MAX(IptStartDate) as IptStartDate FROM PatientIptWorkup GROUP BY PatientId
			) 
			iptStart ON icf.PatientId = iptStart.PatientId
		LEFT JOIN 
			(
				SELECT * FROM (
					SELECT PatientId,ReasonForDiscontinuation,IptDiscontinuationReason,IptEvent, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIptOutcome 
				) o WHERE o.RowNum = 1
			)
			iptOutcome ON iptOutcome.PatientId = icf.PatientId
		LEFT JOIN LookupItem l1 ON l1.Id = IptEvent 
		LEFT JOIN LookupItem l2 ON l2.id = IptDiscontinuationReason
	) r
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

all_visits_cte AS (
	SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId, ProviderName,UserId,GroupId FROM (
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID,ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY VisitDate DESC) as RowNum FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
			UNION
			SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			UNION
			SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
	) visits WHERE VisitDate < = @endDate AND RowNum = 1
),


last_visit_cte_wo_provider AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId,LastProvider,Visitdate, ProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, CAST(VisitDate AS DATE) AS Visitdate, ProviderName, PatientMasterVisitId, UserId lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),


last_visit_cte AS (
	SELECT lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, LastVisitdate, PatientMasterVisitId, lastProvider, ProviderName as LastProviderName FROM last_visit_cte_wo_provider v
--		INNER JOIN providers_cte p ON p.UserID = v.lastProvider
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

gc_last_visit_cte AS (
	SELECT lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by v.PatientId Order By visitDate Desc) as rowNum, v.PatientId, VisitDate LastVisitdate, v.PatientMasterVisitId, UserId lastProvider, ProviderName as LastProviderName FROM all_visits_cte v 
		INNER JOIN PatientEncounter e ON v.PatientId = e.PatientId AND v.PatientMasterVisitId = e.PatientMasterVisitId
		WHERE e.EncounterTypeId = 1482 AND  v.PatientMasterVisitId > 0
--		INNER JOIN providers_cte p ON p.UserID = v.lastProvider
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

last_visit_filtered_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, v.UserId lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM all_visits_cte v INNER JOIN mst_User u ON v.UserId = u.UserID
		WHERE VisitDate <= @endDate AND VisitDate >= @startDate
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

all_clinical_encounters_cte AS (
	SELECT        e.PatientId, e.CreatedBy AS ProviderId, PatientMasterVisit.VisitDate, e.PatientMasterVisitId
	FROM            PatientEncounter AS e INNER JOIN
							 PatientMasterVisit ON e.PatientMasterVisitId = PatientMasterVisit.Id
	WHERE        (e.EncounterTypeId = 1482)
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId,v.UserID lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM all_visits_cte v INNER JOIN mst_User u ON v.UserId = u.UserID
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
		SELECT PatientID, PregnancyStatus, LMP, EDD,VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientID Order BY LMP DESC) as RowNum,Outcome,DateOfOutcome,Parity,[ANC/PNC] FROM (
			SELECT        PI.Id, PI.PatientId, PI.LMP, CASE WHEN l1.name = 'PG' THEN PI.EDD ELSE NULL END AS EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.Name AS PregnancyStatus,P.Outcome,P.DateOfOutcome, P.Parity ,CASE pi.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END AS [ANC/PNC] 
			FROM            PregnancyIndicator AS PI INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
			LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND P.PatientMasterVisitId = PI.PatientMasterVisitId
			-- WHERE p.CreateDate < = @endDate		
		) pgs
	) p WHERE RowNum = 1 
),
-- select * from Pregnancy
-- select * from PregnancyIndicator
all_pregnancy_cte AS (
	SELECT * FROM (
		SELECT PatientID, PregnancyStatus, LMP, EDD,VisitDate,Outcome,DateOfOutcome,PatientMasterVisitId , [ANC/PNC],Parity FROM (
			SELECT        PI.Id, PI.PatientId, PI.LMP, CASE WHEN L1.Name ='NPG' THEN NULL ELSE PI.EDD END AS EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.DisplayName AS PregnancyStatus,P.Outcome,P.DateOfOutcome,pi.PatientMasterVisitId,CASE WHEN l1.Name = 'PG' THEN 'ANC' ELSE CASE pi.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END END AS [ANC/PNC],Parity 
			FROM            PregnancyIndicator AS PI INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
			LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND P.PatientMasterVisitId = PI.PatientMasterVisitId
			WHERE pi.VisitDate < = @endDate -- AND pi.VisitDate > = @startDate		
		) pgs 
	) p  
),

pregnancy_indicator_cte AS (
	SELECT PatientId, [ANC/PNC],PregnancyStatus,VisitDate FROM (
		SELECT PatientID, PregnancyStatus, LMP, EDD,VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientID Order BY LMP DESC) as RowNum , [ANC/PNC] FROM (
			SELECT        PID.Id, PID.PatientId, PID.LMP, PID.EDD, CAST(PID.CreateDate AS DATE) as VisitDate, L1.Name AS PregnancyStatus,CASE piD.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END AS [ANC/PNC] 
			FROM            PregnancyIndicator AS PID INNER JOIN LookupItem L1 ON PID.PregnancyStatusId = L1.Id
			WHERE pid.VisitDate < = @endDate -- AND pi.VisitDate > = @startDate		
		) pgs 	
	) pid WHERE RowNum =1
),

patient_baseline_assessment_cte As (
	Select pba.CD4Count As BaselineCD4, pba.WHOStagename As BaselineWHOStage, pba.PatientId From (
		Select Row_Number() Over (Partition By PatientBaselineAssessment.PatientId Order By PatientBaselineAssessment.CreateDate) As rowNum, PatientBaselineAssessment.PatientId, PatientBaselineAssessment.CreateDate, PatientBaselineAssessment.CD4Count, PatientBaselineAssessment.WHOStage, (Select LookupItem_1.Name From dbo.LookupItem As LookupItem_1 Where LookupItem_1.Id = dbo.PatientBaselineAssessment.WHOStage) As WHOStagename From PatientBaselineAssessment Where (PatientBaselineAssessment.CD4Count Is Not Null) Or (PatientBaselineAssessment.WHOStage Is Not Null)

	) pba Where pba.rowNum = 1
), 

bluecard_bl_who_stage_cte AS (
	SELECT PatientId, WHOStage, VisitDate, 2 AS bpriority FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY VisitDate ASC) as r, PatientId,WHOStage,VisitDate FROM (
			SELECT        s.PatientId, l.Name AS WHOStage, CAST(PatientMasterVisit.VisitDate AS DATE) AS VisitDate
			FROM            PatientWHOStage AS s INNER JOIN
									 LookupItem AS l ON l.Id = s.WHOStage INNER JOIN
									 PatientMasterVisit ON s.PatientMasterVisitId = PatientMasterVisit.Id
			UNION
			SELECT        p.id as patientId, CASE d.Name WHEN 1 THEN 'Stage1' WHEN 2 THEN 'Stage2' WHEN 3 THEN 'Stage3' WHEN 4 THEN 'Stage4' END  AS WHOStage, CAST(ord_Visit.VisitDate AS DATE) AS VisitDate
			FROM            ord_Visit INNER JOIN
									 dtl_PatientStage AS s INNER JOIN
									 mst_Decode AS d ON s.WHOStage = d.ID INNER JOIN
									 Patient AS p ON s.Ptn_pk = p.ptn_pk ON ord_Visit.Visit_Id = s.Visit_Pk
			WHERE        (ISNUMERIC(d.Name) = 1)
		) who
	) who WHERE r= 1
),

greencard_bl_who_stage_cte AS (
	SELECT PatientId,WHOStage,VisitDate,bpriority FROM (
		SELECT        Row_Number() Over (Partition By s.PatientId Order By s.CreateDate) As rowNum, s.PatientId, l.Name AS WHOStage, CAST(v.VisitDate AS DATE) AS VisitDate, 1 AS bpriority
		FROM            PatientBaselineAssessment AS s INNER JOIN
								 LookupItem AS l ON l.Id = s.WHOStage INNER JOIN
								 PatientMasterVisit AS v ON s.PatientMasterVisitId = v.Id WHERE s.WHOStage != 500
	) who WHERE rowNum = 1
),

baseline_who_stage_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY bPriority, VisitDate) as rowNum, PatientId, WHOStage, VisitDate FROM (
			SELECT * FROM greencard_bl_who_stage_cte 
			UNION
			SELECT * FROM bluecard_bl_who_stage_cte
		) who
	) who WHERE rowNum = 1
),

ever_on_tb_tx_cte AS (
	SELECT PatientId, 'Y' as EverBeenOnTBTx FROM (
		SELECT PatientId, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIcf WHERE OnAntiTbDrugs = 1 AND ABS(DATEDIFF(M,CreateDate,@endDate)) <= 12
	) tb WHERE tb.RowNum =1 
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

stability_cte AS (
	SELECT patientId,Categorization FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By CreateDate Desc) as rowNum,s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, CreateDate as CategorizationDate from PatientCategorization s
		 WHERE s.CreateDate <= @endDate
	) s WHERE rowNum = 1
),

stable_clients_cte AS (
	SELECT * FROM stability_cte WHERE Categorization = 'Stable'
),

all_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientId,MONTH(CreateDate) ORDER BY CreateDate) as RowNum, s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, PatientMasterVisitId, CAST(s.CreateDate AS DATE) as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate <= @endDate and s.CreateDate >=@startDate
	) s WHERE RowNum = 1
),

all_curr_month_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientId,MONTH(CreateDate) ORDER BY CreateDate DESC) as RowNum, s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, PatientMasterVisitId, CAST(s.CreateDate AS DATE) as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate >= DATEADD(M, DATEDIFF(M, 0, @startDate), 0) and s.CreateDate <= EOMONTH(@startDate)
	) s WHERE RowNum = 1
),

all_prev_month_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientId,MONTH(CreateDate) ORDER BY CreateDate DESC) as RowNum, s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, PatientMasterVisitId, CAST(s.CreateDate AS DATE) as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate >= DATEADD(M,DATEDIFF(M, 0, DATEADD(M, -1, @startDate)),0) and s.CreateDate <= EOMONTH(DATEADD(M, -1, @startDate))
	) s WHERE RowNum = 1
),

all_prev_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum, s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, PatientMasterVisitId, CAST(s.CreateDate AS DATE) as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate <= DATEADD(M,DATEDIFF(M, 0, @startDate),0)
	) s WHERE RowNum = 1
),

dc_cte AS (
	SELECT PatientId, DCModel FROM (
		SELECT        PA.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY PA.CreateDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		WHERE CreateDate <= @endDate
	) dc WHERE dc.RowNum = 1
),

curr_month_dc_cte AS (
	SELECT PatientId, DCModel FROM (
		SELECT        PA.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY PA.CreateDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		WHERE PA.CreateDate >= DATEADD(M, DATEDIFF(M, 0, @startDate), 0) and PA.CreateDate <= EOMONTH(@startDate)
	) dc WHERE dc.RowNum = 1
),

prev_month_dc_cte AS (
	SELECT PatientId, DCModel FROM (
		SELECT        PA.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY PA.CreateDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		WHERE PA.CreateDate >= DATEADD(M,DATEDIFF(M, 0, DATEADD(M, -1, @startDate)),0) and PA.CreateDate <= EOMONTH(DATEADD(M, -1, @startDate))
	) dc WHERE dc.RowNum = 1
),

prev_dc_cte AS (
	SELECT PatientId, DCModel FROM (
		SELECT        PA.PatientId, PA.DifferentiatedCareId, PA.CreateDate, L.Name, L.DisplayName as DCModel,
		ROW_NUMBER() OVER (PARTITION BY PA.PatientId ORDER BY PA.CreateDate DESC) as RowNum 
		FROM            PatientAppointment AS PA INNER JOIN
								 LookupItem AS L ON PA.DifferentiatedCareId = L.Id
		WHERE PA.CreateDate <= DATEADD(M,DATEDIFF(M, 0, @startDate),0)
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
		select ROW_NUMBER() OVER (Partition by pia.PatientId Order By CreateDate Desc) as rowNum, prg.PregnancyStatus, pia.PatientId,pia.VisitDate,pia.PlanningToConceive3M,pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,l1.DisplayName as PartnerHIVStatus,l2.DisplayName as ServiceForEligibleClient,l3.DisplayName as ReasonForFPIneligibility, pia.patientMasterVisitId, prg.[ANC/PNC], prg.Parity from PatientPregnancyIntentionAssessment pia 
		LEFT JOIN LookupItem l1  on pia.PartnerHivStatus = l1.Id
		LEFT JOIN LookupItem l2  on pia.ServiceForEligibleClient = l2.Id
		LEFT JOIN LookupItem l3  on pia.ReasonForFPIneligibility = l3.Id
		LEFT JOIN all_pregnancy_cte prg on pia.PatientMasterVisitId = prg.PatientMasterVisitId
		WHERE pia.VisitDate >= @startDate AND pia.VisitDate <= @endDate
	) lpia WHERE rowNum = 1
),


fp_method_cte AS (
	SELECT      DISTINCT fp.patientMasterVisitId, fpm.PatientId, l.DisplayName AS FPMethod,fp.VisitDate, fp.ReasonNotOnFPId
	FROM            PatientFamilyPlanning AS fp INNER JOIN
							 PatientFamilyPlanningMethod AS fpm ON fp.Id = fpm.PatientFPId INNER JOIN
							 LookupItem AS l ON fpm.FPMethodId = l.Id
	WHERE fp.VisitDate <= @endDate and fp.VisitDate >= DATEADD(M, -6, @endDate)
),

fp_cte AS (
	SELECT PatientId, CurrentlyOnFp, ReasonNotOnFp, VisitDate, PatientMasterVisitId, id,
		MethodsCount = (select COUNT(Distinct FPMethodId) FROM PatientFamilyPlanningMethod fpm WHERE fpm.PatientFPId = fp.Id)
	  FROM (
		SELECT fp.id, ROW_NUMBER() OVER (Partition by fp.PatientId Order By fp.VisitDate Desc) as rowNum, PatientId, CASE fp.FamilyPlanningStatusId WHEN  1 THEN 'Y' WHEN 2 THEN 'N' ELSE 'W' END AS CurrentlyOnFp, l.DisplayName as ReasonNotOnFp,VisitDate,PatientMasterVisitId FROM  
			PatientFamilyPlanning fp LEFT JOIN LookupItem l ON fp.ReasonNotOnFPId = l.Id 
		WHERE VisitDate <= @endDate AND VisitDate >= DATEADD(M,-9,@endDate)
	) fp WHERE fp.rowNum = 1
),

last_fp_method_cte AS (
	SELECT DISTINCT fp.PatientId, l.DisplayName AS FPMethod,PatientMasterVisitId FROM PatientFamilyPlanningMethod fpm INNER JOIN (
			SELECT * FROM fp_cte WHERE VisitDate <= @endDate AND VisitDate >= DATEADD(YYYY,-1, @startDate)
	) fp ON fp.Id = fpm.PatientFPId	
	INNER JOIN LookupItem AS l ON fpm.FPMethodId = l.Id
),

all_fp_pia_cte AS (
	SELECT 
		pia.PatientId,pia.PatientMasterVisitId,pr.PregnancyStatus,pr.LMP,pr.EDD,pr.[ANC/PNC],fp.CurrentlyOnFp,pia.ClientEligibleForFP,pia.PlanningToConceive3M,pia.ServiceForEligibleClient 
		,fpmethod = STUFF((
			  SELECT ',' + fpm.FpMethod
			  FROM fp_method_cte fpm
			  WHERE fpm.PatientMasterVisitId = fp.PatientMasterVisitId 
			  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
		pia.VisitDate
	FROM all_pia_cte pia  
	LEFT JOIN fp_cte fp ON fp.PatientMasterVisitId = pia.PatientMasterVisitId 
	LEFT JOIN all_pregnancy_cte pr ON pr.PatientMasterVisitId = pia.PatientMasterVisitId	 	
),

condom_cte AS (
	-- utilizing condom
	select DISTINCT PatientId, 'Y' as UtilizingCondom from fp_method_cte WHERE FPMethod = 'Condoms'
),

high_vl_cte AS (
	SELECT * FROM (
		SELECT  ROW_NUMBER() OVER (Partition by v.PatientId Order By v.VLDate Desc) as rowNum,v.VLDate as LastHighVLDate, v.VLResults as LastHighVL ,v.patientId
		FROM all_vl_cte v 
		WHERE v.VLResults >= 1000 AND (v.VLDate >= @startDate AND v.VLDate <= @endDate )
	) hv WHERE hv.rowNum = 1
),

hiv_diagnosis_cte AS (
	SELECT PatientId, hivDiagnosisDate FROM (
		SELECT ROW_NUMBER() OVER (Partition by h.PatientId Order By h.CreateDate Desc) as rowNum, PatientId, CAST(HivDiagnosisDate AS DATE) AS HivDiagnosisDate FROM PatientHivDiagnosis h WHERE HIVDiagnosisDate > '1900-01-01'
	) hd WHERE hd.rowNum = 1
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

otz_cte AS (
	select PatientId,OTZNumber FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, CAST(M.OTZNumber AS nvarchar(10)) AS OTZNumber FROM mst_Patient M INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk WHERE OTZNumber IS NOT NULL
	) ti WHERE rowNUm = 1
),
all_tca_cte AS (
		SELECT p.PatientId, CAST(AppointmentDate AS DATE) as AppointmentDate, CAST(VisitDate as DATE) as Visitdate, l.Name as VisitStatus FROM PatientAppointment p INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id 
		INNER JOIN LookupItem l ON L.Id = StatusId
		WHERE (VisitDate <= @endDate AND ABS(DATEDIFF(M,VisitDate, AppointmentDate)) < = 6) OR AppointmentDate <= @endDate
		UNION
		SELECT p.id as PatientId,CAST(AppDate AS DATE) as AppointmentDate,CAST(o.VisitDate AS DATE) as VisitDate, '' from dtl_PatientAppointment a INNER JOIN Patient p ON a.Ptn_pk = p.ptn_pk INNER JOIN ord_Visit o  ON o.Visit_Id = a.Visit_pk
		WHERE VisitDate <= @endDate -- AND VisitDate >= @startDate
),

last_tca_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY VisitDate DESC,AppointmentDate DESC) AS rowNUm, * FROM all_tca_cte 
	) tca WHERE rowNUm = 1
),

secondlast_tca_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY VisitDate DESC,AppointmentDate DESC) AS rowNUm, * FROM all_tca_cte 
	) tca WHERE rowNUm = 2
),

thirdlast_tca_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY VisitDate DESC,AppointmentDate DESC) AS rowNUm, * FROM all_tca_cte 
	) tca WHERE rowNUm = 3
),

last_year_cte AS (
	SELECT id as PatientId FROM Patient_ids
),

care_cte AS (
	SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlDate AS DATE) VlResultsDate, vv.VLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, cd4.CD4Results,cd4.CD4Date, a.PatientStatus,a.ExitDate,lv.LastProviderName
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
	LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
	INNER JOIN mch_cte mch ON mch.patientId = a.PatientID
	WHERE EnrollmentDate <= @endDate
),

dead_cte AS (

	SELECT        PatientId, ExitReason, CAST(ExitDate as DATE) AS ExitDAte, CareEndingNotes
	FROM            (
	SELECT        PatientCareending.PatientId, LookupItem.Name AS ExitReason, PatientCareending.ExitDate, CAST(PatientCareending.CareEndingNotes AS NVARCHAR(100)) as CareEndingNotes
	FROM            PatientCareending INNER JOIN
							 LookupItem ON PatientCareending.ExitReason = LookupItem.Id
	WHERE        (PatientCareending.DeleteFlag = 0)
	UNION 
	SELECT        Patient.Id AS PatientId, mst_Decode.Name AS ExitReason, CAST(dtl_PatientCareEnded.CareEndedDate AS DATE) AS ExitDate, '' as CareEndingNotes
	FROM            dtl_PatientCareEnded INNER JOIN
							 Patient ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk INNER JOIN
							 mst_Decode ON dtl_PatientCareEnded.PatientExitReason = mst_Decode.ID
	) pce WHERE ExitReason = 'Death' 
	AND YEAR(ExitDAte) BETWEEN 2012 AND 2018

),

ae_list_tce AS (
	SELECT mp.PatientEnrollmentID, ae.AdverseEventId, ae.PatientId, L.Name as AdverseEvent, ae.EventCause,ae.Action,CAST(ae.CreateDate AS DATE) as EventDate,curr.Regimen, pr.ProviderName from AdverseEvent ae 
	INNER JOIN LookupItem l ON ae.AdverseEventId = l.Id
	INNER JOIN curr_treatmenttracker_cte curr ON curr.PatientId = ae.PatientId
	INNER JOIN providers_cte pr ON pr.UserID = ae.CreateBy 
	INNER JOIN patient p ON p.id = ae.PatientId
	INNER JOIN mst_Patient mp ON mp.Ptn_Pk = p.ptn_pk 
	WHERE ae.CreateDate BETWEEN @StartDate AND @EndDate

),

ae_summary_tce AS (
	SELECT        ae.AdverseEvent, Count(ae.PatientId) as Clients,
	Regimens = STUFF ((SELECT DISTINCT ','+Regimen FROM ae_list_tce WHERE AdverseEventId=ae.AdverseEventId FOR XML PATH('')) , 1 , 1 , '' ),
	DrugList = STUFF((SELECT DISTINCT ','+EventCause FROM AdverseEvent WHERE AdverseEventId=ae.AdverseEventId FOR XML PATH('')) , 1 , 1 , '' )
	FROM            ae_list_tce AS ae 
	WHERE ae.EventDate BETWEEN @StartDate AND @EndDate
	GROUP BY ae.AdverseEvent, ae.AdverseEventId
),

all_fp_pia_pr_summary_cte AS (
	SELECT 
		Id,
		PatientId,
		Age,
		VisitDate,
		PregnancyStatus,
		LMP,
		EDD,
		[ANC/PNC],
		OnFP,
		fpmethod,
		ClientEligibleForFP,
		PlanningToConceive3M,
		ServiceForEligibleClient,	
		ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY PregnancyStatus DESC, VisitDate DESC) as RowNum1
	FROM (
		SELECT DISTINCT
			a.PatientId as Id,
			a.EnrollmentNumber as PatientId,
			a.CurrentAge as Age,
			av.VisitDate,
			fpp.VisitDate as AssessmentDate,
			fpp.PregnancyStatus,
			fpp.LMP,
			fpp.EDD,
			fpp.[ANC/PNC],
			fpp.CurrentlyOnFp as OnFP,
			fpp.fpmethod,
			fpp.ClientEligibleForFP,
			fpp.PlanningToConceive3M,
			fpp.ServiceForEligibleClient
		 FROM all_Patients_cte a 
			INNER JOIN all_visits_cte av ON av.PatientId = a.PatientID
			LEFT JOIN all_fp_pia_cte fpp ON fpp.PatientMasterVisitId = av.PatientMasterVisitId
		WHERE a.Sex = 'F'
		AND av.VisitDate BETWEEN @startDate AND @endDate
	) pp
),

all_who_stage_cte AS (
	SELECT DISTINCT PatientID,PatientMasterVisitId FROM PatientWHOStage
),

all_ctx_cte AS (
	SELECT o.PatientId,o.PatientMasterVisitId 
	FROM  ord_PatientPharmacyOrder o 
	INNER JOIN dtl_PatientPharmacyOrder d ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
	INNER JOIN mst_drug dr ON dr.Drug_pk = d.Drug_Pk WHERE (dr.DrugName LIKE '%COTRI%' OR dr.DrugName LIKE '%Dapson%')
	AND o.PatientId IS NOT NULL AND o.PatientMasterVisitId IS NOT NULL
),

all_sti_cte AS (
	SELECT DISTINCT PatientId, PatientMasterVisitId FROM PatientPHDP WHERE Phdp = 76
),

all_patient_ipt_cte AS (
	SELECT DISTINCT PatientId, PatientMasterVisitId FROM (
		SELECT patientId,CreateDate,PatientMasterVisitId FROM PatientIcf -- WHERE EverBeenOnIpt = 1 OR OnIpt = 1
		UNION 
		SELECT patientId, CreateDate,PatientMasterVisitId FROM PatientIptWorkup -- WHERE StartIpt  = 1
		UNION
		SELECT PatientId,Createdate,PatientMasterVisitId FROM PatientIptOutcome
	) ipt 
),

all_tbscreening_cte AS (
	SELECT        Id, PatientId, PatientMasterVisitId, CreatedBy as [Provider], CreateDate as VisitDate
	FROM            PatientScreening
	WHERE        (ScreeningTypeId = 4)
),
all_nutrition_assessment_cte AS (
	SELECT        Id, PatientId, PatientMasterVisitId, CreatedBy as [Provider], CreateDate as VisitDate
	FROM            PatientScreening
	WHERE        (ScreeningTypeId = 12)
),

all_adherence_assessment_cte AS (
	SELECT DISTINCT PatientID,PatientMasterVisitId FROM AdherenceAssessment
),

all_arv_adherence_outcomes_cte AS (
	SELECT PatientId,AdherenceOutcome,PatientMasterVisitId FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY CreateDate DESC) as RowNum,li.Name as AdherenceOutcome, PatientId,PatientMasterVisitId FROM AdherenceOutcome ao
		LEFT JOIN LookupItem li ON li.Id = ao.Score WHERE ao.AdherenceType = 34
	) ao WHERE RowNum = 1
),

all_ctx_adherence_outcomes_cte AS (
	SELECT PatientId,AdherenceOutcome,PatientMasterVisitId FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY CreateDate DESC) as RowNum,li.Name as AdherenceOutcome, PatientId,PatientMasterVisitId FROM AdherenceOutcome ao
		LEFT JOIN LookupItem li ON li.Id = ao.Score WHERE ao.AdherenceType = 35
	) ao WHERE RowNum = 1
),

ever_on_dtg_cte AS (
	SELECT distinct PatientId FROM all_treatmenttracker_cte t WHERE Regimen LIKE '%DTG%'
),

ever_on_efv_cte AS (
	SELECT distinct PatientId FROM all_treatmenttracker_cte t WHERE Regimen LIKE '%EFV%'
),


dtg_start_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line
		FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen LIKE '%DTG%' AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t WHERE t.rowNum = 1	
),

dtg_end_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line
		FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen LIKE '%DTG%' AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t WHERE t.rowNum = 1		
),

efv_start_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line
		FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen LIKE '%EFV%' AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t WHERE t.rowNum = 1	
),

efv_end_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line
		FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen LIKE '%EFV%' AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t WHERE t.rowNum = 1		
),

ever_on_efv_cte_never_dtg AS (
	SELECT e.PatientId FROM ever_on_efv_cte e LEFT JOIN ever_on_dtg_cte d ON e.PatientId = d.PatientId WHERE d.PatientId IS NULL
),

lmp_at_last_visit_cte AS (
	SELECT LMP, EDD, PAtientId FROM (
		SELECT LMP,EDD,PatientId, ROW_NUMBER() OVER (PARTITION BY PAtientId ORDER BY CReateDate DESC) AS RowNUm FROM PregnancyIndicator 
	) lmp WHERE RowNUm = 1
),

ltfu_cte AS (
	SELECT *, DATEADD(D,30,t.AppointmentDate) tc FROM last_tca_cte t WHERE DATEADD(D,30,t.AppointmentDate) < @endDate AND DATEADD(D,30,t.AppointmentDate) >= @startDate -- DATEADD(D,-30,t.AppointmentDate) BETWEEN @startDate AND @endDate
),

adolescent_review_cte AS (
	SELECT PatientId, ReviewDate, p.ProviderName AS ReviewedBy FROM PatientClinicalReviewChecklist r
	INNER JOIN providers_cte p ON p.UserID = r.CreatedBy
		WHERE ReviewDate BETWEEN @StartDate and @endDate
),

art_adherence_cte AS (
	SELECT PatientId,AdherenceScore FROM (
		SELECT a.PatientId, li.Name as AdherenceScore, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) AS rown FROM AdherenceOutcome a INNER JOIN LookupItem li ON a.Score = li.Id
		WHERE AdherenceType = 34
	) adh WHERE adh.rown = 1

),

completed_ipt_outcome_cte AS (
	SELECT PatientId, 'Y' AS CompletedIpt FROM  (
		SELECT io.PatientId, li.Name AS IptOutcome, ROW_NUMBER() OVER (PARTITION BY io.PatientId ORDER BY io.CreateDate DESC) AS rown FROM PatientIptOutcome io  LEFT JOIN PatientIptWorkup iw  ON iw.PatientId = io.PatientId 
		INNER JOIN LookupItem li ON li.Id = io.IptEvent
		WHERE IptEvent = 525
	) ipto WHERE ipto.rown = 1
)
/*
-- Adolescent reviews
SELECT 
	a.PatientID as ID, a.EnrollmentNumber as PatientId, a.PatientName,a.currentAge, a.Sex, ad.ReviewDate, ad.ReviewedBy 
FROM all_Patients_cte a 
INNER JOIN adolescent_review_cte ad ON a.PatientID = ad.PatientId
return
*/
/*
-- Pregnant clients without outcomes
SELECT 
	a.PatientID as ID, a.EnrollmentNumber as CCCNumber, mch.MCHNumber, a.PatientName, pr.LMP,pr.EDD, a.PhoneNumber, a.ContactName, a.ContactPhoneNumber, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus
FROM all_Patients_cte a
INNER JOIN (
	SELECT * FROM (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY LMP) as rown FROM PregnancyOutcomeView WHERE PregnancyStatus = 'Pregnant' AND Outcome IS NULL
		) pr1 WHERE pr1.rown = 1
	) pr ON pr.PatientId = a.PatientID 
LEFT JOIN mch_cte mch ON mch.PatientId = a.PatientId
*/

/*
-- Patient Contacts
SELECT 
	a.PatientID as ID, a.EnrollmentNumber as CCCNumber, a.PatientName, a.PhoneNumber, a.ContactName, a.ContactPhoneNumber, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus
FROM all_Patients_cte a
return;

*/
/*
--- DTG AND Pregnancy
--- Victor RADIDA
SELECT a.EnrollmentNumber as CCCNumber,a.PatientName,a.DateOfBirth,a.Sex,cttx.Regimen, ds.RegimenDate as DTGStart,de.RegimenDate as DTGEnd, /*lmp.LMP*/ pg.LMP,pg.EDD,pg.Outcome FROM all_patients_cte a 
INNER JOIN ever_on_dtg_cte d ON a.PatientID = d.PatientId
INNER JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
INNER JOIN dtg_start_cte ds ON ds.PatientId = a.PatientID
LEFT JOIN dtg_end_cte de ON de.PatientId = a.PatientID
LEFT JOIN PregnancyOutcomeView pg ON pg.PatientId = a.PatientID
-- LEFT JOIN lmp_at_last_visit_cte lmp ON lmp.PAtientId = a.PatientID
WHERE a.Sex = 'F' AND a.currentAge BETWEEN 15 AND 51
return
*/
/*
--- EVER ON EFV NOT ON DTG 
--- Victor RADIDA
SELECT a.EnrollmentNumber as CCCNumber,a.PatientName,a.DateOfBirth,a.Sex,cttx.Regimen, ds.RegimenDate as EFVStart,de.RegimenDate as EFVEnd, /*lmp.LMP*/ pg.LMP,pg.EDD,pg.Outcome FROM all_patients_cte a 
INNER JOIN ever_on_efv_cte_never_dtg d ON a.PatientID = d.PatientId
INNER JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
INNER JOIN efv_start_cte ds ON ds.PatientId = a.PatientID
LEFT JOIN efv_end_cte de ON de.PatientId = a.PatientID
LEFT JOIN (SELECT PAtientId,LMP,EDD,Outcome FROM PregnancyOutcomeView WHERE PregnancyStatus = 'Pregnant') pg ON pg.PatientId = a.PatientID
-- LEFT JOIN lmp_at_last_visit_cte lmp ON lmp.PAtientId = a.PatientID
WHERE a.Sex = 'F' AND a.currentAge BETWEEN 15 AND 51 AND a.PatientID = 50
*/

/*
SELECT a.PatientId as Id,'JOT' as Facility, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen,ittx.TLE400 as StartRegimenTLE400, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,cttx.TLE400 as CurrentRegimenTLE400,cttx.regimenLine as CurrentRegimenLine,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
*/
/*
--select * from pregnancy_cte where PregnancyStatus = 'PG' AND Outcome > 0
--return
select * from all_pregnancy_cte WHERE PregnancyStatus = 'Pregnant' AND Outcome > 0
return

select * from PregnancyOutcomeView -- WHERE Outcome IS NOT NULL
select * from ae_list_tce
return;
select a.PatientID, a.EnrollmentNumber, a.PhoneNumber, a.ContactName,a.ContactPhoneNumber,a.PatientName from all_Patients_cte a
UNION
select a.PatientID, ti.TINumber as EnrollmentNumber, a.PhoneNumber, a.ContactName,a.ContactPhoneNumber, a.PatientName from all_Patients_cte a
INNER JOIN ti_cte ti ON ti.PatientId = a.PatientID
return
-- select * from fp_cte WHERE PatientId = 49
*/
--TODO -- JUST RUN
/*
select * from all_treatmenttracker_cte WHERE PatientId = 5432

select * from curr_treatmenttracker_cte WHERE PatientId =31453
select * from prev_treatmenttracker_cte WHERE PatientId =31453
*/

/*
--HIGH VL 
-- SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.Regimen as currentRegimen,a.NextAppointmentDate,v.VLDate as LastVLDate, v.VLResults as LastVL,a.PatientStatus,rl.RelationsName,rl.RelationsSex,rl.Relationship,rl.RelationsTestingDate,rl.RelationsTestingResult,rl.ReferredToCare FROM all_Patients_cte a 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.Regimen as currentRegimen,a.NextAppointmentDate,v.VLDate as LastVLDate, v.VLResults as LastVL,a.PatientStatus FROM all_Patients_cte a 
LEFT JOIN vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN curr_treatmenttracker_cte r ON a.PatientID = r.PatientId
-- LEFT JOIN relationship_cte rl ON rl.patientId = a.PatientID
WHERE v.VLResults >= 1000 AND v.VLDate >= @startDate
AND v.VLDate <= @endDate
--WHERE RegimenType IS NOT NULL
*/


/*
--LOW VL - LLV - LOW LEVEL VIREMIA
SELECT a.PatientID as ID,
	a.EnrollmentNumber as PatientId,mch.MCHNumber, a.PatientName,a.sex,
	--a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
	a.currentAge, 
	CASE WHEN a.currentAge >= 0 AND a.currentAge <= 9 THEN 'Age group 0-9' WHEN a.currentAge >= 10 AND a.currentAge <= 19 THEN 'Age group 10-19' WHEN a.currentAge >=20 AND a.currentAge <=24 THEN 'Age group 20-24' WHEN a.currentAge >=25 AND a.currentAge <=34 THEN 'Age group 25-34' ELSE 'Age group Over 35' END as AgeCategory, 
	a.[EnrollmentDate ] as RegistrationDate,
--	r.Regimen as currentRegimen,
--	40-200, 201-500, 501-1000
	CAST(v.VLDate AS DATE) as LastVLDate, v.VLResults as LastVL, 
	CASE WHEN v.VLResults >= 40 AND v.VLResults <= 200 THEN 'VL 040-200' WHEN v.VLResults >= 201 AND v.VLResults <= 500 THEN 'VL 201-500' WHEN v.VLResults >=501 AND v.VLResults <=1000 THEN 'VL 501-1000' ELSE 'VL Unknown' END as VLCountCategory, 	
--	CONCAT(YEAR(v.VLDate),'-',RIGHT(CONCAT('0',MONTH(v.VLDate)),2)) as VLPeriod,
	a.NextAppointmentDate,
	a.PatientStatus,
	lv.LastProviderName,
	lv.lastVisitDate
--	,CAST (a.ExitDate AS DATE) as ExitDate
FROM all_Patients_cte a 
LEFT JOIN vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.patientId = a.PatientID
--  LEFT JOIN curr_treatmenttracker_cte r ON a.PatientID = r.PatientId
WHERE 
	a.PatientStatus = 'Active'
	AND (v.VLResults <= 1000 AND v.VLResults >= 40) 
--  AND (v.VLDate BETWEEN @startDate AND @endDate)
	AND DATEDIFF (D,a.NextAppointmentDate, @endDate) < 90
--  WHERE RegimenType IS NOT NULL
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
SELECT 
	a.EnrollmentNumber as PatientId,a.PatientName,a.sex, v.LastHighVL,v.LastHighVLDate, vl.VLResults AS LastVL, vl.VlDate AS LastVLDate,sv.VLResults as SecondLastVL,sv.VlResultsDate as SecondLastVLDate, a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,
	CASE 
	WHEN a.PatientStatus = 'Death' THEN 'Dead'
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut'
	WHEN DateDiff(D, a.NextAppointmentDate, @endDate) < 30 THEN 'Active'
	WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 30 AND
	DateDiff(D, a.NextAppointmentDate, @endDate) < 90 THEN 'Defaulter'
	WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 90 OR
	DateDiff(D, a.NextAppointmentDate, @endDate) IS NULL THEN 'LTFU'
	ELSE a.PatientStatus END AS PatientStatus
FROM all_Patients_cte a 
INNER JOIN high_vl_cte v ON a.PatientId = v.patientId
INNER JOIN vl_cte vl ON vl.patientId = a.patientId
LEFT JOIN second_last_vl_cte sv ON sv.patientId = v.patientId 
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
--LEFT JOIN relationship_cte rl ON rl.patientId = a.PatientID
--WHERE v.SampleDate >= '2017-01-01'
--WHERE RegimenType IS NOT NULL
return
*/
/*
--PENDING VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,v.VLDate as VLDate, NULL as VL,a.PatientStatus,lv.lastVisitDate,lv.LastProviderName FROM all_Patients_cte a 
INNER JOIN pending_vl_results_cte v ON a.PatientId = v.patientId
LEFT JOIN regimen_cte r ON a.PatientID = r.PatientId
LEFT JOIN last_visit_cte lv ON lv.PatientId = r.patientId
WHERE DATEDIFF(M,v.VLDate,@enddate) <= 6
--WHERE RegimenType IS NOT NULL
*/


/*
--ALL HIGH VL 
SELECT a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,a.currentAge, a.[EnrollmentDate ] as RegistrationDate,r.RegimenType as currentRegimen,a.NextAppointmentDate,CAST(v.VLDate AS DATE) as VLDate, v.VLResults as VL, CONCAT(YEAR(v.VLDate),'-',RIGHT(CONCAT('0',MONTH(v.VLDate)),2)) as VLPeriod, CONCAT(CAST(v.VLDate AS CHAR(3)),'-',YEAR(v.VLDate)) as VLPeriod2, a.PatientStatus, a.ExitDate FROM all_Patients_cte a 
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
SELECT /*a.PatientId as Id,*/ a.EnrollmentNumber as PatientId,/*otz.OTZNumber,*/a.PatientName,a.sex,a.currentAge, cttx.Regimen as CurrentRegimen
,/*a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,*/
/*a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,*/
vl.VLDate as VLDate, vl.VLResults as VL,
/*CASE WHEN a.currentAge >= 0 AND a.currentAge <= 9 THEN 'Age group 0-9' WHEN a.currentAge >= 10 AND a.currentAge <= 14 THEN 'Age group 10-14' WHEN a.currentAge >=15 AND a.currentAge <=19 THEN 'Age group 15-19' ELSE 'Age group 20-24' END as AgeCategory,*/  
CAST(lvst.lastVisitDate AS DATE) AS LastVisitDate,NextAppointmentDate
,DATEDIFF(M,a.NextAppointmentDate,@endDate) as NoOfMonthsLost
,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
CAST(a.ExitDate AS DATE) as ExitDate 
 FROM all_Patients_cte a 
--LEFT JOIN vitals_cte vi ON vi.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_results_cte vl ON vl.patientId = a.PatientID
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN otz_cte otz ON otz.PatientID = a.PatientID
--WHERE a.currentAge BETWEEN 10 and 19 -- OTZ Adolescents
--WHERE a.currentAge BETWEEN 0 and 24
WHERE a.currentAge BETWEEN 0 and 5
--  AND PatientStatus = 'Active'
-- AND (PatientStatus = 'Active' OR PatientStatus = 'LostToFollowUp')
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') <= 12
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') >= 3
 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND PatientStatus = 'Active'
ORDER BY a.PatientID
*/

/*
-- PAEDS
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId
-- ,otz.OTZNumber
,a.PatientName,a.sex,a.currentAge, cttx.Regimen as CurrentRegimen
,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
/*a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,*/
vl.VLDate as VLDate, vl.VLResults as VL,
-- CASE WHEN a.currentAge >= 0 AND a.currentAge <= 9 THEN 'Age group 0-9' WHEN a.currentAge >= 10 AND a.currentAge <= 14 THEN 'Age group 10-14' WHEN a.currentAge >=15 AND a.currentAge <=19 THEN 'Age group 15-19' ELSE 'Age group 20-24' END as AgeCategory,  
CAST(lvst.lastVisitDate AS DATE) AS LastVisitDate,NextAppointmentDate
--,DATEDIFF(D,a.NextAppointmentDate,@endDate) as NoOfMonthsLost
,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
--CAST(a.ExitDate AS DATE) as ExitDate 
 FROM all_Patients_cte a 
--LEFT JOIN vitals_cte vi ON vi.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_results_cte vl ON vl.patientId = a.PatientID
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
-- LEFT JOIN otz_cte otz ON otz.PatientID = a.PatientID
WHERE a.currentAge <= 9
  AND PatientStatus = 'Active'
-- AND (PatientStatus = 'Active' OR PatientStatus = 'LostToFollowUp')
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') <= 12
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') >= 3
 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND PatientStatus = 'Active'
ORDER BY a.PatientID
*/

/*
--ADOLESCENTS LOST TO FOLLOW UP
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,otz.OTZNumber,a.PatientName,a.sex,a.currentAge, cttx.Regimen as CurrentRegimen
,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
/*a.[EnrollmentDate ] as RegistrationDate,
art.ARTInitiationDate as ARTStartDate,*/
vl.VLDate as VLDate, vl.VLResults as VL,
CASE WHEN a.currentAge >= 0 AND a.currentAge <= 9 THEN 'Age group 0-9' WHEN a.currentAge >= 10 AND a.currentAge <= 14 THEN 'Age group 10-14' WHEN a.currentAge >=15 AND a.currentAge <=19 THEN 'Age group 15-19' ELSE 'Age group 20-24' END as AgeCategory,  
CAST(lvst.lastVisitDate AS DATE) AS LastVisitDate,NextAppointmentDate
,DATEDIFF(M,a.NextAppointmentDate,@endDate) as NoOfMonthsLost
,a.PatientStatus,CAST(a.ExitDate AS DATE) as ExitDate 
 FROM all_Patients_cte a 
--LEFT JOIN vitals_cte vi ON vi.PatientId =a.PatientID
LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
LEFT JOIN vl_results_cte vl ON vl.patientId = a.PatientID
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN otz_cte otz ON otz.PatientID = a.PatientID
WHERE a.currentAge <= 20
AND cttx.Regimen IS NOT NULL
--  AND PatientStatus = 'Active'
 AND (PatientStatus = 'Active' OR PatientStatus = 'LostToFollowUp')
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') <= 12
-- AND DATEDIFF(M,a.NextAppointmentDate,'2018-11-30') >= 3
 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90
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
--Weights for DTG clients
*/

/*
SELECT c.*, a.VisitDate,a.Weight FROM care_cte c LEFT JOIN 
all_vitals_cte a ON c.Id = a.PatientId AND a.VisitDate BETWEEN c.CurrentRegimenStartdate AND c.lastVisitDate
-- WHERE c.Id = 2510
ORDER BY PatientId, VisitDate 
*/

/*
-- DEAD Clients
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlDate AS DATE) VlResultsDate, vv.VLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, cd4.CD4Results,cd4.CD4Date, D.ExitDate, D.ExitReason,D.CareEndingNotes
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
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.patientId = a.PatientID
INNER JOIN dead_cte D ON D.PatientId = a.PatientID 
*/

/*
-- ALL PATIENTS
SELECT a.PatientId as Id,'JOT' as Facility, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen,ittx.TLE400 as StartRegimenTLE400, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,cttx.TLE400 as CurrentRegimenTLE400,cttx.regimenLine as CurrentRegimenLine,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, pttx.regimenLine as PrevRegimenLine, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(vv.VlDate AS DATE) VlResultsDate, vv.VLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, cd4.CD4Results,cd4.CD4Date, 
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
a.ExitDate,lv.LastProviderName
-- ,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName
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
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.patientId = a.PatientID
-- INNER JOIN last_year_cte l ON l.patientId = a.PatientId
--LEFT JOIN relationship_cte rl ON rl.PatientId = a.PatientID AND rl.Relationship NOT IN ('Child', 'Sibling')
--LEFT JOIN regimen_cte r ON r.patientId = a.PatientID
WHERE EnrollmentDate <= @endDate -- AND a.PatientID = 33223
--AND EnrollmentDate >= @startDate
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
-- AND a.PatientId = 34127
*/

/*
-- SWITCHES
SELECT 
	a.PatientId as Id, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,cttx.regimenLine as CurrentRegimenLine,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, pttx.regimenLine as PrevRegimenLine,
	CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, 
	a.PatientStatus,a.ExitDate
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.patientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND pttx.Regimen IS NOT NULL
AND cttx.RegimenDate BETWEEN @startDate AND @endDate
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
DATEDIFF (D,a.NextAppointmentDate, '2018-09-30') >= 90
--AND [EnrollmentDate ] BETWEEN @startDate AND @endDate
--WHERE art.ARTInitiationDate <= '2018-04-30' AND art.ARTInitiationDate >= '2017-01-01'
--AND (a.ExitDate > '2017-06-30' or a.ExitDate IS NULL) -- AND 
AND (PatientStatus = 'Active') 
ORDER BY a.PatientID
*/

/*
-- New ART Initiations
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,ti.TINumber,mch.MCHNumber,a.PatientName,a.sex,a.currentAge,
a.PatientType,
--,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.EnrollmentDate as RegistrationDate,
it.ARTInitiationDate as ARTStartDate,
it.Regimen as StartRegimen,
tt.Regimen as CurrentRegimen,
vl.VlDate as VLDate, vl.VLResults as VL,
a.PatientStatus,
a.ExitDate,
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
LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
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
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId/*,a.PatientName*/,--a.currentAge,
a.Sex,CAST(a.DateOfBirth AS DATE) as DOB, a.currentAge,
a.EnrollmentDate as RegistrationDate,
a.PhoneNumber,
a.ContactName,
a.ContactPhoneNumber,
art.ARTInitiationDate as ARTStartDate,
art.Regimen as StartRegimen,
art_cur.Regimen as CurrentRegimen,
-- art_cur.RegimenLine as CurrentRegimenLine,
(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
as DateOFSwitch,
art_prev.Regimen as PrevRegimen,
/*art_prev.RegimenDate as PrevRegimenStartDate,
art_prev.RegimenLine as PrevRegimenLine,*/
CAST(pr.LMP AS DATE) LMP,
CAST(pr.EDD AS DATE) EDD,
pr.PregnancyStatus as PregnancyStatusAtLastVisit,
/*	fp.CurrentlyOnFp as [Currently on a Family planning method], 
	WhichMethod = STUFF((
          SELECT ',' + lfp.FpMethod
          FROM last_fp_method_cte lfp
          WHERE lfp.PatientMasterVisitId = fp.PatientMasterVisitId
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
	'' as [Pregnant while on family planning], fp.MethodsCount,*/
vl.VlDate as LastVLDate,
vl.VLResults as LastVL,
vl2.VlResultsDate as SecondLastVLDate,
vl2.VLResults as SecondLastVL,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 THEN 'LTFU' ELSE 'Active' 
END as PatientStatus,
lvst.lastProviderName,
--'' as LastServicePoint,
NextAppointmentDate
 FROM all_Patients_cte a 
 LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
-- INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte art_prev ON art_prev.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN second_last_vl_cte vl2 ON vl2.patientId = a.PatientID
LEFT JOIN pregnancy_cte pr ON pr.patientId = a.PatientID
LEFT JOIN fp_cte fp ON a.PatientId=fp.PatientId 
WHERE 
EnrollmentDate  <= @endDate 
-- AND EnrollmentDate  >= @startDate
AND art_cur.Regimen LIKE '%DTG%'
-- AND a.CurrentAge BETWEEN 18 AND 49
-- AND a.Sex = 'F'
 AND a.PatientStatus = 'Active'
AND DATEDIFF (D,a.NextAppointmentDate, @startDate) < 90
-- AND a.PatientID = 9895
ORDER BY a.PatientID
*/

--select * from gcPatientView WHERE EnrollmentNumber = '13939-22382'
--select * from all_prev_stability_cte WHERE PatientId = 44
--return

/*
--DC MAPPING EXTRCATION
--atandi
SELECT 
/*a.PatientID as ID,*/ 
a.EnrollmentNumber as [CCC Number],a.sex,CAST(a.DateOfBirth AS DATE) as DOB, a.CurrentAge as Age,
-- a.EnrollmentDate as [Date Enrolled],
art.Regimen as RegimenAtStart,
art.ARTInitiationDate as ARTStartDate,
pttx.Regimen as PrevRegimen,
pttx.RegimenDate as PrevRegimenStartDate,
art_cur.Regimen as CurrentRegimen,
(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
as DateOFSwitchToCurrentRegimen,
art_cur.regimenLine,
pr.LMP,
pr.EDD,
pr.PregnancyStatus,
'' AS currentlyOnFp,
FpMethod = STUFF((
          SELECT DISTINCT ',' + fp.FpMethod
          FROM fp_method_cte fp
          WHERE fp.PatientId = a.PatientId
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
a.ContactPhoneNumber,
'' AS Occupation,
CONCAT(l.Location, ' - ', l.WardName, ' - ', l.LandMark)  as Residence,
st.Categorization,
dc.DCModel as StableModel,
st.CategorizationDate,
svl.VLResults as SecondLastVL,
svl.VlResultsDate as SecondLastVLDate,
vl.VLResults as LastVL,
vl.VLDate as LastVLDate,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 THEN 'LTFU' ELSE 'Active' 
END as PatientStatus,
lvst.lastProviderName,
lvst.LastVisitDate,
CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,
csta.Categorization AS CurrentMonthStabilityStatus,
csta.CategorizationDate AS CurrentMonthCategorizationDate,
cmdc.DCModel as CurrentMonthStableModel,
psta.Categorization AS PrevStabilityStatus,
psta.CategorizationDate AS PrevCategorizationDate,
pdc.DCModel as PrevStableModel
--pmsta.Categorization AS PrevMonthStabilityStatus,
--pmsta.CategorizationDate AS PrevMOnthCategorizationDate
-- ISNULL(tb.EverBeenOnTBTx,'N') as EverBeenOnTBTx,
-- ISNULL(ipt.Completed, 'N') as CompletedIPT,
/* blwho.WHOStage as WHOStageAtEnrollement,
bl.BaselineCD4 as CD4AtEnrollment,
CASE WHEN (blwho.WHOStage = 'stage1' OR blwho.WHOStage = 'stage2' or blwho.WHOStage IS NULL or blwho.WHOStage IS NULL or blwho.WHOStage = 'Unknown') AND (bl.BaselineCD4 >= 200 OR bl.BaselineCD4 IS NULL) THEN 
	'Well'
ELSE
	'Advanced'
END
as [Well/Advanced],
adh.AdherenceAsessmentOUtcome,
vit.BMI,
pg.PregnancyStatus as PregnancyAtLastVisit,
'' AS Service,
CASE WHEN st.Categorization = 'Stable' THEN dc.DCModel ELSE '' END AS StableModel,
CAST(lvst.lastVisitDate AS DATE) AS lastVisitDate,
NextAppointmentDate,
a.PatientStatus,
a.ExitDate,
lvst.lastProviderName*/
FROM all_Patients_cte a 
LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN second_last_vl_cte svl ON svl.patientId = a.PatientID
--LEFT JOIN ever_on_tb_tx_cte tb ON tb.patientId = a.PatientID
--LEFT JOIN patient_baseline_assessment_cte bl ON bl.patientId = a.PatientID
--LEFT JOIN baseline_who_stage_cte blwho ON blwho.patientId = a.PatientID
--LEFT JOIN completed_ipt_cte ipt ON ipt.patientId = a.PatientID
--LEFT JOIN adherence_cte adh ON adh.patientId = a.PatientID
--LEFT JOIN vitals_cte vit ON vit.patientId = a.PatientID
LEFT JOIN pregnancy_cte pg ON pg.patientId = a.PatientID
LEFT JOIN stability_cte st on st.PatientId = a.PatientID
LEFT JOIN dc_cte dc on dc.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
LEFT JOIN pregnancy_cte pr ON pr.patientId = a.PatientID
LEFT JOIN fp_cte fp ON a.PatientId=fp.PatientId 
LEFT JOIN location_cte l on l.PatientId = a.PatientID
LEFT JOIN all_curr_month_stability_cte csta ON csta.PatientId = a.PatientID
LEFT JOIN curr_month_dc_cte cmdc ON cmdc.PatientId = a.PatientID
--LEFT JOIN all_prev_month_stability_cte pmsta ON pmsta.PatientId = a.PatientId
--LEFT JOIN prev_month_dc_cte pmdc ON pmdc.PatientId = a.PatientID
LEFT JOIN all_prev_stability_cte psta ON psta.PatientId = a.PatientId
LEFT JOIN prev_dc_cte pdc ON pdc.PatientId = a.PatientID
LEFT JOIN last_tca_cte ltca ON ltca.PatientId = a.PatientID
WHERE 
EnrollmentDate  <= @endDate 
AND DATEDIFF (D,a.NextAppointmentDate, @endDate) < 90
-- AND EnrollmentDate  >= @startDate
--AND a.PatientId = 44
ORDER BY a.PatientID
*/
/*
-- PIA DATA
SELECT 
	a.PatientId as Id,
	a.EnrollmentNumber as PatientId,
	a.PatientName,
	a.Sex,
	a.CurrentAge,
	CASE WHEN a.currentAge >= 0 AND a.currentAge <= 14 THEN 'Age group 0-14' WHEN a.currentAge >= 15 AND a.currentAge <= 19 THEN 'Age group 15-19' WHEN a.currentAge >=20 AND a.currentAge <=49 THEN 'Age group 20-49' ELSE 'Age 50 and above' END as AgeCategory, 	tt.Regimen,
	tt.Regimen,
	a.[EnrollmentDate] as RegistrationDate,
	art.ARTInitiationDate,
	a.NextAppointmentDate,
	CAST(pia.visitDate AS DATE) as PIAAssessmentDate,
	--fpm.fpmethod,
	pia.PlanningToConceive3M,
	pia.RegularMenses,
	pia.ClientEligibleForFP,
	pia.PartnerHIVStatus,
	pia.ServiceForEligibleClient,
	pia.ReasonForFPIneligibility,
	FpMethod = STUFF((
          SELECT ',' + fp.FpMethod
          FROM fp_method_cte fp
          WHERE fp.PatientId = a.PatientId
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
	a.PatientStatus,
	a.ExitDate,
	vst.lastVisitdate,
	pia.PregnancyStatus as PregnancyStatusAtAssessment
 FROM all_Patients_cte a 
	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
	LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
	--LEFT JOIN fp_method_cte fpm ON a.PatientId=fpm.PatientId 
	LEFT JOIN last_pia_cte pia ON pia.PatientId = a.PatientID
	LEFT JOIN last_visit_filtered_cte vst ON vst.PatientId = a.PatientID
WHERE a.Sex = 'F'
AND vst.lastVisitDate BETWEEN @startDate and @endDate
--AND a.PatientID = 7458

 --WHERE ABS(DATEDIFF(M,pia.VisitDate,getdate())) <= 2
*/

/*
 -- PIA TEMPLATE - DR. KIDIGA
SELECT 
--	a.PatientId as Id,
	a.EnrollmentNumber as PatientId,
	ti.TINumber,
	a.CurrentAge as Age,
	'' AS Parity,
	pid.[ANC/PNC],
	'' AS [PMTCT/CCC],
	'' AS [KP/NP],
	a.MaritalStatus as [Marital Status],
	a.EducationLevel as [Level of Education],
	'' as Occupation,
	CONCAT(l.Location, ' - ', l.WardName, ' - ', l.LandMark)  as Residence,
	hd.HIVDiagnosisDate as [Date tested positive],
	art.ARTInitiationDate as [Date started ART],
	tt.Regimen as [ART regimen],
	adh.AdherenceAsessmentOUtcome as [Adherence Levels],
	vl.VLResults as [Latest viral load],
	c.UtilizingCondom as [Utilizing condom],
	pia.PlanningToConceive3M as [Intending to get pregnant],
	fp.CurrentlyOnFp as [Currently on a Family planning method], 
	WhichMethod = STUFF((
          SELECT ',' + fp.FpMethod
          FROM last_fp_method_cte fp
          WHERE fp.PatientId = a.PatientId
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
	'' as [Pregnant while on family planning],
	ISNULL(fp.ReasonNotOnFp,'') as [Reason not on Family planning], 
	'' as [Screened for PDT],
	CASE WHEN pid.PregnancyStatus = 'PG' AND DATEDIFF(Y, @endDate, pid.VisitDate) <= 1 THEN 'Y' 
	ELSE CASE WHEN pid.PregnancyStatus = 'NPG' THEN 'N' 
	ELSE 'NA' END  END
	as [Pregnant in the last one yr],
	'' as [Identified pregnant at which gestation],
	CASE WHEN DCModel = NULL THEN 'NA' ELSE CASE WHEN dc.DCModel = 'Standard Care' THEN 'N' ELSE 'Y' END END as [Is patient on DC],
	dc.DCModel,
	CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,  
	 CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 THEN 'LTFU' ELSE 'Active' 
	 END as PatientStatus,
 		a.ExitDate,
	vst.lastVisitdate,
	vst.LastProviderName
 FROM all_Patients_cte a 
	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
	LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
	LEFT JOIN fp_cte fp ON a.PatientId=fp.PatientId 
	LEFT JOIN last_pia_cte pia ON pia.PatientId = a.PatientID
	left join pregnancy_indicator_cte pid ON pid.PatientId = a.PatientID
	LEFT JOIN last_visit_cte vst ON vst.PatientId = a.PatientID
	LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID 
	LEFT JOIN adherence_cte adh ON adh.PatientId = a.PatientID
	LEFT JOIN vl_cte vl ON vl.PatientId = a.PatientID
	LEFT JOIN condom_cte c ON c.PatientId = a.PatientID
	LEFT JOIN location_cte l ON l.PatientId = a.PatientID
	LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientId 
	LEFT JOIN dc_cte dc ON dc.PatientId = a.PatientID
WHERE a.Sex = 'F'
-- AND DATEDIFF (D,a.NextAppointmentDate, @endDate) < 30
-- AND a.PatientID = 875
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
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, hvl.LastHighVLDate,hvl.LastHighVL,CAST(vv.VlDate AS DATE) LastVlResultsDate, vv.VLResults as LastVLResults, CAST(svv.VlResultsDate AS DATE) SecondLastVlResultsDate, svv.VLResults SecondLastVLResults, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,  a.PatientStatus,lv.LastProviderName,
CONCAT(l.Location, ' - ', l.WardName, ' - ', l.LandMark)  as PhysicalAddress
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
LEFT JOIN location_cte l ON l.PatientId = a.PatientID
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
/*
-- All Stable
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex,a.currentAge,a.PhoneNumber,a.ContactPhoneNumber,a.ContactName,
a.[EnrollmentDate] as RegistrationDate,
a.PatientStatus,
NextAppointmentDate,
s.CategorizationDate,
CONCAT(YEAR(s.CategorizationDate),'-',RIGHT(CONCAT('0',MONTH(s.CategorizationDate)),2)) as Period,
s.Categorization
FROM all_patients_cte a INNER JOIN
all_stability_cte s ON a.PatientID = s.PatientId
order by a.PatientId
return
*/
/*
-- All Visits
SELECT DISTINCT a.EnrollmentNumber as CCCNumber, CAST(v.VisitDate AS DATE) AS VisitDate
-- ,p.ProviderName, 
FROM all_Patients_cte a 
INNER JOIN all_visits_cte v ON a.PatientId = v.PatientId 
INNER JOIN providers_cte p oN v.lastProvider = p.UserID 
WHERE v.VisitDate BETWEEN @startDate AND @endDate  AND p.GroupID = 5 
*/

/*
-- ALL PATIENTS
SELECT 'JOOTRH' as FacilityName,'' as [Month], a.EnrollmentNumber as [Patient Unique No],a.sex as Gender, a.currentAge as [Age],  CAST(a.[EnrollmentDate] AS DATE) as [Date enrolled into Care],'ART' as [Type], CAST(art_init_date.ARTInitiationDate AS DATE) as [Date initiated on ART], ittx.Regimen as [Regimen at Initiation], cttx.Regimen as CurrentRegimen,cttx.RegimenDate as [Date Started Current Regimen], pttx.Regimen as PreviousRegimen, pttx.RegimenDate as [Previous Regimen Start Date], bcd4.Cd4Results [Baseline CD4], cd4.CD4Results [Last CD4 Count], cd4.CD4Date as [Last cd4 date], bvl.VLResults as [Baseline Viral Load], bvl.VlDate as [Baseline Viral Load date], vv.VLResults as [Last Viral Load],vv.VLDate as [Last Viral Load Date],  CAST(lv.lastVisitDate AS DATE) [date last seen],/*CAST(a.NextAppointmentDate AS DATE) [Date .expected],*/ ltca.AppointmentDate as [Last TCA],sltca.AppointmentDate as [Second Last TCA],tltca.AppointmentDate as [Third Last TCA], a.PatientStatus,a.ExitDate,a.CareEndingNotes
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
LEFT JOIN baseline_cd4_results_cte bcd4 ON bcd4.PatientId = a.PatientID
LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
LEFT JOIN last_tca_cte ltca ON ltca.PatientId = a.PatientID
LEFT JOIN secondlast_tca_cte sltca ON sltca.PatientId = a.PatientID
LEFT JOIN thirdlast_tca_cte tltca ON tltca.PatientId = a.PatientID
-- INNER JOIN last_year_cte l ON l.patientId = a.PatientId
--LEFT JOIN relationship_cte rl ON rl.PatientId = a.PatientID AND rl.Relationship NOT IN ('Child', 'Sibling')
--LEFT JOIN regimen_cte r ON r.patientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
--AND EnrollmentDate >= @startDate
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


-- SELECT * FROM ae_list_tce
/*
-- ADVERSE EVENTS SUMMARY
SELECT 
	aes.AdverseEvent,
	aes.Clients, 
	aes.Regimens,
	aes.DrugList 
FROM ae_summary_tce aes
return
*/
-- select * from post_viremia_vl_cte WHERE PatientId = 276
--select * from all_vl_cte WHERE PatientId = 1149
-- select * from resuppression_cte -- where patientid = 1149
--where DATEDIFF(D,FirstVlDate,SecondVLDate) < 30

/*
-- Resupression linelist. Before and after viremia clinic
SELECT
 a.PatientId as Id, a.EnrollmentNumber as PatientId,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType,a.currentAge, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate,
 CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,  
 CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 THEN 'LTFU' ELSE 'Active' 
 END as PatientStatus,
 ressup.FirstVlDate, ressup.FirstVLResult,ressup.SecondVlDate,ressup.SecondVlResult,ressup.Scenario
-- ,lv.LastProviderName
FROM all_Patients_cte a 
INNER JOIN resuppression_cte ressup ON a.PatientId = ressup.PatientId
LEFT JOIN last_visit_cte lv ON a.PatientID = lv.PatientId
LEFT JOIN first_visit_cte fv ON a.PatientID = fv.PatientId
*/

/*
-- DQA TEMPLATE - MCH CLIENTS
SELECT 
	a.PatientId as Id, a.EnrollmentNumber as PatientId,a.sex, CAST(a.DateOfBirth AS DATE) AS DateOfBirth, hd.HivDiagnosisDate, CAST(a.EnrollmentDate AS DATE) AS EnrollmentDate,
	SUBSTRING(bl.WHOStage, PATINDEX('%[0-9]%',bl.WHOStage),1) AS WHOStage, 
	CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, 
	REPLACE(CASE WHEN ittx.Regimen IS NULL THEN NULL ELSE SUBSTRING(ittx.Regimen,CHARINDEX('(',ittx.Regimen)+1,LEN(ittx.Regimen) - CHARINDEX('(',ittx.Regimen) - 1) END, ' + ', '/') as StartRegimen, 
	REPLACE(CASE WHEN cttx.Regimen IS NULL THEN NULL ELSE SUBSTRING(cttx.Regimen,CHARINDEX('(',cttx.Regimen)+1,LEN(cttx.Regimen) - CHARINDEX('(',cttx.Regimen) - 1) END, ' + ', '/') as CurrentRegimen,
	bvl.VLResults AS BaselineVL,CAST(bvl.VlDate AS DATE) AS BaselineVLDate, CAST(vv.VlDate AS DATE) LastVlResultsDate, vv.VLResults as LastVLResults, CAST(lv.lastVisitDate AS DATE) lastVisitDate,mch.MCHNumber
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
LEFT JOIN baseline_who_stage_cte bl ON bl.PatientId = a.PatientID
INNER JOIN mch_cte mch ON mch.patientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND DATEDIFF(D, a.NextAppointmentDate, @endDate) < 30
AND a.PatientStatus = 'Active'
AND lv.LastProviderName IN ('Onywera Susan', 'Nancy Odhiambo')

/*
-- DQA TEMPLATE - PSC CLIENTS
SELECT 
	a.PatientId as Id, a.EnrollmentNumber as PatientId,a.sex, CAST(a.DateOfBirth AS DATE) AS DateOfBirth, hd.HivDiagnosisDate, CAST(a.EnrollmentDate AS DATE) AS EnrollmentDate,
	SUBSTRING(bl.WHOStage, PATINDEX('%[0-9]%',bl.WHOStage),1) AS WHOStage, 
	CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, 
	REPLACE(CASE WHEN ittx.Regimen IS NULL THEN NULL ELSE SUBSTRING(ittx.Regimen,CHARINDEX('(',ittx.Regimen)+1,LEN(ittx.Regimen) - CHARINDEX('(',ittx.Regimen) - 1) END, ' + ', '/') as StartRegimen, 
	REPLACE(CASE WHEN cttx.Regimen IS NULL THEN NULL ELSE SUBSTRING(cttx.Regimen,CHARINDEX('(',cttx.Regimen)+1,LEN(cttx.Regimen) - CHARINDEX('(',cttx.Regimen) - 1) END, ' + ', '/') as CurrentRegimen,
	bvl.VLResults AS BaselineVL,CAST(bvl.VlDate AS DATE) AS BaselineVLDate, CAST(vv.VlDate AS DATE) LastVlResultsDate, vv.VLResults as LastVLResults, CAST(lv.lastVisitDate AS DATE) lastVisitDate
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
LEFT JOIN baseline_who_stage_cte bl ON bl.PatientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND DATEDIFF(D, a.NextAppointmentDate, @endDate) < 30
AND a.PatientStatus = 'Active'
AND lv.LastProviderName NOT IN ('Onywera Susan', 'Nancy Odhiambo')
*/


-- select * from all_visits_cte WHERE PatientMasterVisitId = 164023

-- select * from PatientMasterVisit WHERE id = 164023

-- select * from PatientIptWorkup WHERE PatientMasterVisitId =168091

-- SELECT * FROM patientIptInitiations WHERE PatientId  = 845
/*
select * from all_visits_cte v 
INNER JOIN patientIptInitiations ipt ON v.PatientID = ipt.PatientId AND v.PatientMasterVisitId = ipt.PatientMasterVisitId
INNER JOIN providers_cte p ON p.UserID = ipt.IPTStartedBy
WHERE v.PatientId  = 845
*/
/*
-- IPT Initiaitions
SELECT DISTINCT  a.PatientID as ID, a.EnrollmentNumber as CCCNumber, a.EnrollmentDate,/*CAST(v.VisitDate AS DATE) as Visitdate,*/ CAST(ipt.IPTStart AS DATE) as DateStartedIpt, p.ProviderName as IptStartedBy FROM all_Patients_cte a 
INNER JOIN patientIptInitiations ipt ON a.PatientID = ipt.PatientId
INNER JOIN all_visits_cte v ON v.PatientMasterVisitId = ipt.PatientMasterVisitId AND v.PatientId = ipt.PatientId
INNER JOIN providers_cte p ON p.UserID = ipt.IPTStartedBy
-- WHERE a.PatientID = 9952
*/

/*
-- ClinicalEncounters
SELECT DISTINCT  a.PatientID as ID, a.EnrollmentNumber as CCCNumber, a.EnrollmentDate,CAST(v.VisitDate AS DATE) as Visitdate,p.ProviderName FROM all_Patients_cte a 
INNER JOIN all_clinical_encounters_cte v ON  v.PatientId = a.PatientId
INNER JOIN providers_cte p ON p.UserID = v.ProviderId
WHERE v.VisitDate BETWEEN @startDate AND @endDate
*/
/*
select * from all_visits_cte WHERE 
PatientId = 2701
AND VisitDate BETWEEN @startDate AND @endDate
AND PatientMasterVisitId >0
ORDER BY VisitDate DESC
*/
*/
/*
-- Pregnancy, PIA, FP
SELECT DISTINCT --top 100
	a.PatientId as Id,
	a.EnrollmentNumber as PatientId,
	a.CurrentAge as Age,
	av.VisitDate,
	fpp.PregnancyStatus,
	fpp.LMP,
	fpp.EDD,
	fpp.[ANC/PNC],
	fpp.CurrentlyOnFp as OnFP,
	fpp.fpmethod,
	fpp.ClientEligibleForFP,
	fpp.PlanningToConceive3M,
	fpp.ServiceForEligibleClient
 FROM all_Patients_cte a 
	INNER JOIN all_visits_cte av ON av.PatientId = a.PatientID
	LEFT JOIN all_fp_pia_cte fpp ON fpp.PatientMasterVisitId = av.PatientMasterVisitId
WHERE a.Sex = 'F'
-- AND a.PatientId = 7458
AND av.PatientMasterVisitId > 0
AND av.VisitDate BETWEEN @startDate AND @endDate
-- ORDER BY VisitDate DESC
*/
/*
SELECT * FROM fp_cte
WHERE PatientId = 7458
*/
/*
SELECT * FROM all_pia_cte
WHERE PatientId = 7458
*/

/*
	SELECT 
		pia.PatientId,pia.PatientMasterVisitId,pr.PregnancyStatus,
		pia.VisitDate
	FROM all_pia_cte pia  
	-- LEFT JOIN fp_cte fp ON fp.PatientMasterVisitId = pia.PatientMasterVisitId 
	LEFT JOIN all_pregnancy_cte pr ON pr.PatientMasterVisitId = pia.PatientMasterVisitId	 	
	WHERE pia.PatientId = 11952
*/
/*
select * from all_fp_pia_cte
WHERE PatientId  = 11952

SELECT * FROM all_pia_cte
WHERE PatientId = 11952


SELECT * FROM fp_cte fp  
WHERE PatientId = 11952
*/
/*
SELECT * FROM  all_fp_pia_cte pia 
WHERE PatientId = 11952
*/
/*
SELECT * FROM  all_pregnancy_cte pr 
WHERE PatientId = 11952
*/
/*
SELECT * FROM all_fp_pia_pr_summary_cte
WHERE 
 RowNum1 = 1
*/
-- AND 
-- id = 2897


/*
SELECT * FROM all_fp_pia_cte
WHERE PatientId = 7458
*/
/*
-- EVER ON DTG & pregnant
SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId, mch.MCHNumber, a.PatientName,a.sex,a.currentAge,
a.Sex,CAST(a.DateOfBirth AS DATE) as DOB, a.currentAge,
a.EnrollmentDate as RegistrationDate,
a.PhoneNumber,
art.ARTInitiationDate as ARTStartDate,
art.Regimen as StartRegimen,
art_cur.Regimen as CurrentRegimen,
EverOnDTG = (CASE WHEN (SELECT count(patientId) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID AND ptt.Regimen LIKE '%DTG%') > 0 THEN 1 ELSE 0 END),
art_cur.RegimenLine as CurrentRegimenLine,
(SELECT CAST(MIN(ISNULL(ptt.RegimenStartDate,ptt.DispensedByDate)) AS DATE) FROM PatientTreatmentTrackerViewD4T ptt WHERE ptt.PatientID = a.PatientID and ptt.Regimen = art_cur.Regimen) 
as DateOFSwitchToCurrentRegimen,
art_prev.Regimen as PrevRegimem,
art_prev.RegimenDate as PrevRegimenStartDate,
art_prev.RegimenLine as PrevRegimenLine,
CAST(pr.LMP AS DATE) LMP,
CAST(pr.EDD AS DATE) EDD,
pr.VisitDate as PregnancyAssessmentDate,
pr.PregnancyStatus as PregnancyStatusAtLastVisit,
vl.VLResults as LastVL,
vl.VlDate as LastVLDate,
--vl2.VlResultsDate as SecondLastVLDate,
--vl2.VLResults as SecondLastVL,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
lvst.lastProviderName,
--'' as LastServicePoint,
NextAppointmentDate
 FROM all_Patients_cte a 
 LEFT JOIN last_visit_cte lvst ON lvst.PatientId =a.PatientID
-- INNER JOIN screening_cte scr ON scr.PatientId = a.PatientID
INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
LEFT JOIN prev_treatmenttracker_cte art_prev ON art_prev.PatientId = a.PatientID
LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
LEFT JOIN second_last_vl_cte vl2 ON vl2.patientId = a.PatientID
LEFT JOIN pregnancy_cte pr ON pr.patientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.patientId = a.PatientId
--LEFT JOIN last_visit_cte lv ON lv.PatientId  = a.PatientId
WHERE 
EnrollmentDate  <= @endDate 
-- AND EnrollmentDate  >= @startDate
-- AND art_cur.Regimen LIKE '%DTG%'
-- AND a.CurrentAge BETWEEN 18 AND 49
ORDER BY a.PatientID
*/
/*
-- NON-OPTIMIZED CLIENTS - FEMALE REP AGE NOT ON TLE
SELECT --a.PatientID as id,
	a.EnrollmentNumber as PatientId,ti.TINumber,a.sex, a.currentAge, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, 
	REPLACE(CASE WHEN cttx.Regimen IS NULL THEN NULL ELSE SUBSTRING(cttx.Regimen,CHARINDEX('(',cttx.Regimen)+1,LEN(cttx.Regimen) - CHARINDEX('(',cttx.Regimen) - 1) END, ' + ', '/') as CurrentRegimen,
	CAST(a.NextAppointmentDate AS DATE) as AppointmentDate,  CAST(vv.VlDate AS DATE) LastVlDate, vv.VLResults as LastVL, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus,
	a.PhoneNumber, a.ContactName, a.ContactPhoneNumber --,  cttx.Regimen
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
--LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
--LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
--LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
--LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
--LEFT JOIN baseline_who_stage_cte bl ON bl.PatientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND DATEDIFF(D, a.NextAppointmentDate, @endDate) < 30
AND CTTX.regimenLine = 1
AND A.currentAge BETWEEN 15 AND 49
AND A.Sex ='F'
AND a.PatientStatus = 'Active'
AND (cttx.Regimen NOT LIKE '%TDF + 3TC + EFV%'
AND cttx.Regimen NOT LIKE '%TDF + 3TC + DTG%')

*/
/*
-- NON-OPTIMIZED CLIENTS - ADULT MALE ABOVE 15 and FEMALE above 49 NOT ON TLD
SELECT --a.PatientID as id,
	a.EnrollmentNumber as PatientId,ti.TINumber,a.sex, a.currentAge, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, 
	REPLACE(CASE WHEN cttx.Regimen IS NULL THEN NULL ELSE SUBSTRING(cttx.Regimen,CHARINDEX('(',cttx.Regimen)+1,LEN(cttx.Regimen) - CHARINDEX('(',cttx.Regimen) - 1) END, ' + ', '/') as CurrentRegimen,
	CAST(a.NextAppointmentDate AS DATE) as AppointmentDate,  CAST(vv.VlDate AS DATE) LastVlDate, vv.VLResults as LastVL, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus,
	a.PhoneNumber, a.ContactName, a.ContactPhoneNumber --,  cttx.Regimen
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
--LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
--LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
--LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
--LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
--LEFT JOIN baseline_who_stage_cte bl ON bl.PatientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND DATEDIFF(D, a.NextAppointmentDate, @endDate) < 30
AND CTTX.regimenLine = 1
AND ((A.currentAge >= 15
AND A.Sex ='M') OR (A.Sex='F' AND A.currentAge >= 50))
AND a.PatientStatus = 'Active'
AND cttx.Regimen NOT LIKE '%TDF + 3TC + DTG%'
*/
/*
-- NON-OPTIMIZED CLIENTS - FEMALE ON TLD
SELECT --a.PatientID as id,
	a.EnrollmentNumber as PatientId,ti.TINumber,a.sex, a.currentAge, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, 
	REPLACE(CASE WHEN cttx.Regimen IS NULL THEN NULL ELSE SUBSTRING(cttx.Regimen,CHARINDEX('(',cttx.Regimen)+1,LEN(cttx.Regimen) - CHARINDEX('(',cttx.Regimen) - 1) END, ' + ', '/') as CurrentRegimen,
	CAST(a.NextAppointmentDate AS DATE) as AppointmentDate,  CAST(vv.VlDate AS DATE) LastVlDate, vv.VLResults as LastVL, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus,
	a.PhoneNumber, a.ContactName, a.ContactPhoneNumber --,  cttx.Regimen
FROM all_Patients_cte a 
LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
--LEFT JOIN baseline_vl_cte bvl ON bvl.PatientId = a.PatientID
--LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
--LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
--LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
--LEFT JOIN baseline_who_stage_cte bl ON bl.PatientId = a.PatientID
WHERE EnrollmentDate <= @endDate --AND a.PatientID = 15
AND DATEDIFF(D, a.NextAppointmentDate, @endDate) < 30
AND CTTX.regimenLine = 1
AND A.Sex ='F'
AND a.PatientStatus = 'Active'
AND (cttx.Regimen LIKE '%TDF + 3TC + DTG%')
*/
/*
-- SELECT PatientId,VlDate FROM vl_cte vl WHERE  DATEDIFF(YY,vl.VlDate, @endDate) < 1 AND PatientId =4
-- select * from last_vl_sample_in_past_1yr_cte WHERE PatientId = 2006
-- select * from all_tbscreening_cte WHERE PatientID = 80
-- SIMS Preparation Linelist
SELECT DISTINCT a.PatientID as ID, a.EnrollmentNumber as [CCC Number],ti.TINumber,mch.mchNumber,a.PatientName,a.sex, a.currentAge as [Age], a.PatientType,  a.[EnrollmentDate], itx.ARTInitiationDate as ARTStartDate, vl1.SAmpleDate as LastVLSampleDate, lastVl.VlDate as LastVLWithResultDate, lv.LastVisitdate, lv.PatientMasterVisitId,
CASE WHEN aws.patientId IS NULL THEN 'N' ELSE 'Y' END as WHOStage,
CASE WHEN cd4.patientId IS NULL THEN 'N' ELSE 'Y' END as CD4,
CASE WHEN ctx.patientId IS NULL THEN 'N' ELSE 'Y' END as CTX,
CASE WHEN vl1.patientId IS NULL THEN 'N' ELSE 'Y' END as VLSampleInPastIYear,
CASE WHEN vl.patientId IS NULL THEN 'N' ELSE 'Y' END as VLResultInPastIYear,
CASE WHEN sti.patientId IS NULL THEN 'N' ELSE 'Y' END as STIScreening,
CASE WHEN ipt.patientId IS NULL THEN 'N' ELSE 'Y' END as IPT,
CASE WHEN na.patientId IS NULL THEN 'N' ELSE 'Y' END as NutritionAssessment,
CASE WHEN tbs.patientId IS NULL THEN 'N' ELSE 'Y' END as TBScreening,
CASE WHEN adh.patientId IS NULL THEN 'N' ELSE 'Y' END as AdherenceAssessment,
CASE WHEN fpt.patientId IS NULL THEN 'N' ELSE 'Y' END as FamilyPartnerListing,
lv.LastProviderName
FROM all_Patients_cte a 
LEFT JOIN gc_last_visit_cte lv ON lv.PatientId = a.PatientID
LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID 
LEFT JOIN all_who_stage_cte aws ON aws.PatientId = a.PatientID AND aws.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN cd4_results_cte cd4 ON cd4.PatientId = a.PatientID
LEFT JOIN all_ctx_cte ctx ON ctx.PatientId = a.PatientID AND ctx.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN last_vl_result_in_past_1yr_cte vl ON vl.PatientId = a.PatientID
LEFT JOIN last_vl_sample_in_past_1yr_cte vl1 ON vl1.PatientId = a.PatientId
LEFT JOIN all_sti_cte sti ON sti.PatientId = a.PatientID AND sti.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN all_patient_ipt_cte ipt ON ipt.PatientId = a.PatientID AND ipt.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN all_tbscreening_cte tbs ON tbs.PatientId = a.PatientID AND tbs.PatientMasterVisitId = lv.PatientMasterVisitId -- Outcome too
LEFT JOIN all_nutrition_assessment_cte na ON na.PatientId = a.PatientID AND na.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN all_adherence_assessment_cte adh ON adh.PatientId = a.PatientID AND adh.PatientMasterVisitId = lv.PatientMasterVisitId
LEFT JOIN (SELECT DISTINCT PatientId FROM relationship_cte rl) fpt ON fpt.PatientId = a.PatientID
LEFT JOIN vl_cte lastvl ON lastvl.patientId = a.PatientID
LEFT JOIN init_treatmenttracker_cte iTx ON iTx.PatientId = a.PatientID 
WHERE
a.PatientStatus = 'Active'
AND iTx.PatientId IS NOT NULL
AND (DATEDIFF (D,a.NextAppointmentDate, @startDate) < 30)
-- MISSING IPT Screening, TB SCreening, Adherence Assessment, CTX, STI Screening
AND (ipt.PatientId IS NULL OR tbs.PatientId IS NULL OR adh.PatientId IS NULL or ctx.PatientId IS NULL OR sti.PatientId IS NULL)
AND lv.PatientId IS NOT NULL
-- AND ROW_NUMBER() OVER (PARTITION BY a.PatientId ORDER BY a.PAtientId) = 1
-- AND a.PatientID = 225
*/

/*
-- MISSING APPOINTMENTS
SELECT a.PatientId as Id,'JOT' as Facility, a.EnrollmentNumber as PatientId,ti.TINumber,mch.mchNumber,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus,
a.ExitDate,lv.LastProviderName
FROM all_Patients_cte a 
-- LEFT JOIN last_tca_cte tca ON a.PatientID = tca.PatientId
INNER JOIN last_visit_cte lv ON a.PatientID = lv.PatientId
LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
WHERE a.NextAppointmentDate BETWEEN @startDate AND @endDate
AND PatientStatus = 'Active'
AND lv.LastProviderName IN ('Nancy Odhiambo','Onywera Susan','Diana Oketch') 
*/
/*
-- CDC PMTCT - George Odingo
SELECT 
	a.PatientId as Id,
	a.EnrollmentNumber as PatientId,
	CAST(a.DateOfBirth AS DATE) as DOB,
	a.Sex,
	a.EnrollmentDate as CCCEnrollmentDate,
	mch.MCHEnrollmentDate,
	cd4.CD4Results as BaselineCD4,
	who.WHOStage as BaselineWHO,
	bvl.VLResults as BaselineVL,
	vl.VLResults as LastVL,
	vl2.VLResults as SecondLastVL,
	CAST(ittx.ARTInitiationDate AS DATE) As ARTStartDate,
	ittx.Regimen as StartRegimen,
--	cttx.Regimen as CurrentRegimen,
	av.VisitDate,
	vi.Height,
	vi.Weight,
	vi.BMI,
	CONCAT(vi.BPSystolic,'/',vi.BPDiastolic) as BP,
	ado.AdherenceOutcome,
	afpia.PregnancyStatus,
	afpia.PlanningToConceive3M,
	afpia.CurrentlyOnFp,
	afpia.FpMethod,		
	ast.Categorization as StabilityStatus,
  CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 THEN 'LTFU' ELSE 'Active' 
	 END as PatientStatus,
 		a.ExitDate
 FROM all_Patients_cte a 
	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = a.PatientID
	LEFT JOIN curr_treatmenttracker_cte tt ON tt.PatientId = a.PatientID
	LEFT JOIN hiv_diagnosis_cte hd ON hd.PatientId = a.PatientID
	LEFT JOIN vl_cte vl ON vl.PatientId = a.PatientID
	LEFT JOIN second_last_vl_cte vl2 ON vl2.PatientId = a.PatientID
	INNER JOIN mch_cte mch ON mch.PatientID = a.PatientID
	LEFT JOIN baseline_cd4_results_cte cd4 ON cd4.patientId = a.PatientID
	LEFT JOIN baseline_who_stage_cte who ON who.PatientId = a.PatientID
	LEFT JOIN baseline_vl_cte bvl ON bvl.patientId = a.PatientID
	LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientId
	LEFT JOIN all_visits_cte av ON av.PatientId = a.PatientID
	LEFT JOIN all_vitals_cte vi ON vi.PatientMasterVisitId = av.PatientMasterVisitId
	LEFT JOIN all_arv_adherence_outcomes_cte ado ON ado.PatientMasterVisitId = av.PatientMasterVisitId
	LEFT JOIN all_fp_pia_cte afpia ON afpia.PatientMasterVisitId = av.PatientMasterVisitId
	LEFT JOIN all_stability_cte ast ON ast.PatientMasterVisitId = av.PatientMasterVisitId
WHERE a.Sex = 'F'
AND av.VisitDate BETWEEN @startDate AND @endDate
AND av.PatientMasterVisitId > 0
-- AND DATEDIFF (D,a.NextAppointmentDate, @endDate) < 30
-- AND a.PatientID = 875
*/

/*
-- OTZ
SELECT a.PatientId as Id,a.EnrollmentNumber as PatientId,a.PatientName,a.sex, o.OTZNumber,
CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
	WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
	WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
	ELSE a.PatientStatus 
END as PatientStatus
FROM all_Patients_cte a 
INNER JOIN otz_cte o ON a.PatientId = o.PatientId
WHERE len(OTZNumber) > 0

*/
/*
select * from ltfu_cte WHERE PatientId =7344
return 
*/

SELECT 
	a.EnrollmentNumber AS PatientId, 
	ti.TINumber as [JOOT TI Number],
	a.PatientName as [Name],
	a.Sex,
	a.currentAge as [Current Age],
	a.EnrollmentDate as RegistrationDate,
	ittx.Regimen as StartRegimen,
	ittx.ARTInitiationDate as [ART Start Date],
	art.Regimen AS [Current Regimen],
	art.RegimenLine AS [Current Regimen Line],
	cttxdate.Regimendate as [Current Regimen Start Date],
	v.lastVisitDate AS LastVisitDate,
	a.NextAppointmentDate,
	vl.VlDate as LastVLDate,
	vl.vlresults as LastVL,
	v.lastVisitDate,
	v.LastProviderName,
	PhoneNumber,
	a.ContactName,
	a.ContactPhoneNumber,
	--Completed IPT
	ipt.CompletedIpt,
	--DuratinONCurrntRegimen
	DATEDIFF(M, cttxdate.RegimenDate, @endDate ) as DurationOnCurrentRegimen,
	--AdherenceScore
	adh.AdherenceScore,
	--BMI
	vit.BMI,
	--Categorization
	cat.Categorization,
	--DC MOdel
	dc.DCModel,
	--Last VL Sample
	vls.VlSampleDate,
	v.LastProviderName
 FROM all_patients_cte a
--	 INNER JOIN ltfu_cte l ON a.PatientID = l.PatientId
	 INNER JOIN curr_treatmenttracker_cte art ON art.PatientId = a.PatientID 
	 INNER JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
	 LEFT JOIN last_visit_cte v ON v.PatientId = a.PatientID
	 LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
	 LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
	 LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
	 LEFT JOIN vitals_cte vit ON vit.PatientId = a.PatientID
	 LEFT JOIN dc_cte dc ON dc.PatientId = a.PatientID
	 LEFT JOIN stability_cte cat ON cat.PatientId = a.PatientID
	 LEFT JOIN last_vl_sample_cte vls ON vls.patientId = a.PatientID
	 LEFT JOIN art_adherence_cte adh ON adh.PatientId = a.PatientID
	 LEFT JOIN completed_ipt_outcome_cte ipt ON ipt.PatientId = a.PatientID
 WHERE
	 a.PatientStatus = 'Active'
	 AND (DATEDIFF (D,a.NextAppointmentDate, @startDate) < 30)
	--AND v.LastProviderName NOT IN ('Susan Onywera', 'Diana Oketch', 'Nancy Odhiambo', 'Brenda Ondego')
	 --AND dc.DCModel != 'Express Care'
	 AND vit.BMI >= 18.5
	 AND a.currentAge >=20
	 AND adh.AdherenceScore = 'Good'
	 AND DATEDIFF(M, cttxdate.RegimenDate, vl.VlDate) >= 3
	 AND ipt.CompletedIpt = 'Y'
	 AND vl.VLResults <= 400
	 AND DATEDIFF(M, ittx.ARTInitiationDate, @endDate) >= 12
 
-- WHERE a.PatientID= 7344

-- select * from mst_User WHERE UserFirstName = 'Diana' order by UserId DESC
-- select * from PatientAppointment WHERE PatientId = 33259

