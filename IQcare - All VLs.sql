DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate ='2019-02-01';
set @endDate = '2019-02-28';

set nocount off;

WITH all_Patients_cte as (
SELECT   g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, p.PatientName PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, @endDate) AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, NextAppointmentDate, 
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, g.PatientType, tp.MaritalStatus, tp.EducationLevel,ce.ExitReason--, CareEndingNotes
FROM            IQTools_KeHMIS.dbo.tmp_PatientMaster p
INNER JOIN gcPatientView g ON p.PatientPK = g.ptn_pk
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
 ) PA ON g.Id = p.patientId 
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
		WHERE    --    (Results = 'Pending') AND
		         (LabTestId = 3) AND SampleDate <= @endDate AND DATEDIFF(MM,SampleDate, @endDate) <= 12 
	) vlr WHERE RowNum = 1
 ),

  last_vl_result_in_past_1yr_cte AS (
	SELECT PatientId,VlDate,VLResults FROM (
		SELECT        patientId,CAST (SampleDate AS DATE) as VlDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete') AND
		         (LabTestId = 3) AND SampleDate <= @endDate AND DATEDIFF(MM,SampleDate, @endDate) <= 12
	) vlr WHERE RowNum = 1
 ),

 all_vl_cte AS (
	SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults
	FROM            dbo.PatientLabTracker
	WHERE        (Results = 'Complete')
	AND         (LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
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

 all_vitals_cte AS (
	SELECT PatientId, PatientMasterVisitId,Weight,Height,VisitDate FROM ( 
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
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerView t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t
),

curr_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine FROM (
		SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC, t.id DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerView t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
	) t WHERE t.rowNum = 1
),

init_treatmenttracker_cte AS (
	SELECT PatientId,Regimen,RegimenId, t.ARTInitiationDate, Line as regimenLine FROM (
		SELECT RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate ASC, t.RegimenStartDate ASC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerView t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate --and t.RegimenStartDate IS NOT NULL
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
		SELECT t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenStartDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line FROM PatientTreatmentTrackerView t WHERE t.Regimen IS NOT NULL
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
		PatientId, EverBeenOnIpt,IptStartDate,Completed,OnIpt,Discontinued,rfd
	FROM (
		SELECT 
			icf.PatientId
			,CASE WHEN iptOutcome.IptEvent IS NOT NULL THEN 'Y' ELSE CASE WHEN iptStart.IptStartDate IS NOT NULL THEN 'Y' ELSE CASE WHEN icf.EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END END END as EverBeenOnIpt, l1.Name
			,CAST(iptStart.IptStartDate AS  DATE) AS IptStartDate
			,CASE WHEN l1.Name = 'Completed' THEN 'Y' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) >=6 AND l1.Name IS NULL THEN 'Y'  ELSE 'N' END END AS Completed
			,CASE WHEN l1.Name IS NOT NULL THEN 'N' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) <6 THEN 'Y'  ELSE 'N' END END AS OnIpt
			,CASE WHEN l1.Name = 'Discontinued' THEN 'Y' ELSE 'N' END AS Discontinued 
			,ReasonForDiscontinuation as RFD
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
					SELECT PatientId,ReasonForDiscontinuation,IptEvent, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIptOutcome 
				) o WHERE o.RowNum = 1
			)
			iptOutcome ON iptOutcome.PatientId = icf.PatientId
		LEFT JOIN LookupItem l1 ON l1.Id = IptEvent 
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
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
			UNION
			SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			UNION
			SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			WHERE VisitDate < @endDate -- AND VisitDate >= @startDate

		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
	) visits WHERE VisitDate < = @endDate
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
			SELECT        PI.Id, PI.PatientId, PI.LMP, CASE WHEN L1.Name ='NPG' THEN NULL ELSE PI.EDD END AS EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.Name AS PregnancyStatus,P.Outcome,P.DateOfOutcome,pi.PatientMasterVisitId,CASE WHEN l1.Name = 'PG' THEN 'ANC' ELSE CASE pi.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END END AS [ANC/PNC],Parity 
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
		 WHERE s.CreateDate <= @endDate
	) s WHERE rowNum = 1
),

stable_clients_cte AS (
	SELECT * FROM stability_cte WHERE Categorization = 'Stable'
),

all_stability_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY PatientId,MONTH(CreateDate) ORDER BY CreateDate) as RowNum, s.PatientId, Case WHEN Categorization = 1 then 'Stable' ELSE 'Unstable' END as Categorization, CAST(s.CreateDate AS DATE) as CategorizationDate from PatientCategorization s
		WHERE s.CreateDate <= @endDate and s.CreateDate >=@startDate
	) s WHERE RowNum = 1
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
	WHERE fp.VisitDate <= @endDate and fp.VisitDate >= @startDate
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


all_tca_cte AS (
		SELECT p.PatientId, CAST(AppointmentDate AS DATE) as AppointmentDate, CAST(VisitDate as DATE) as Visitdate, l.Name as VisitStatus FROM PatientAppointment p INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id 
		INNER JOIN LookupItem l ON L.Id = StatusId
		WHERE (VisitDate <= @endDate AND ABS(DATEDIFF(M,VisitDate, AppointmentDate)) < = 3) OR AppointmentDate <= @endDate
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


care_cte AS (
	SELECT a.PatientId as Id, a.EnrollmentNumber as PatientId,a.PatientName,a.sex, CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType, '' as RegistrationAge,a.currentAge,  CAST(a.[EnrollmentDate] AS DATE) as RegistrationDate, ittx.Regimen as StartRegimen, CAST(art_init_date.ARTInitiationDate AS DATE) as ARTStartDate, cttx.Regimen as CurrentRegimen,CAST(cttxdate.RegimenDate AS DATE) as CurrentRegimenStartdate,pttx.Regimen as PrevRegimen, CAST(pttxdate.RegimenDate AS DATE) as PrevRegimenStartDate, CAST(fv.firstVisitDate AS DATE) firstVisitDate, CAST(lv.lastVisitDate AS DATE) lastVisitDate,CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate, CAST(av.VlDate AS DATE) VlResultsDate, av.VLResults, cd4.CD4Results,cd4.CD4Date, a.PatientStatus,a.ExitDate,lv.LastProviderName
	FROM all_Patients_cte a 
	LEFT JOIN patient_artintitiation_dates_cte art_init_date ON art_init_date.PatientId = a.PatientID
	LEFT JOIN init_treatmenttracker_cte ittx ON ittx.PatientId = a.PatientID
	LEFT JOIN curr_treatmenttracker_cte cttx ON cttx.PatientId = a.PatientID
	LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
	LEFT JOIN prev_regimen_date_cte pttxdate ON pttxdate.PatientId = a.PatientID
	LEFT JOIN curr_regimen_date_cte cttxdate ON cttxdate.PatientId = a.PatientID
--	LEFT JOIN vl_cte vv ON vv.PatientId = a.PatientID
--	LEFT JOIN second_last_vl_cte svv ON svv.PatientId = a.PatientID
	LEFT JOIN last_visit_cte lv ON lv.PatientId = a.PatientID
	LEFT JOIN first_visit_cte fv ON fv.PatientId = a.PatientID
	LEFT JOIN cd4_results_cte cd4 ON cd4.patientId = a.PatientID
	LEFT JOIN ti_cte ti ON ti.patientId = a.PatientID
	LEFT JOIN all_vl_cte av ON av.patientId = a.PatientID
	WHERE EnrollmentDate <= @endDate
)

select * from care_cte