DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2017-01-01';
set @endDate = '2019-12-31';


BEGIN TRY
drop table #tmpDrugHistory
drop table #tmpVLHistory
END TRY
BEGIN CATCH
END CATCH

;WITH all_Patients_cte as (
SELECT    g.ptn_pk as PatientPk, g.Id as PatientID, g.PersonId, EnrollmentNumber, UPPER(CONCAT(g.FirstName, ' ', REPLACE(g.MiddleName, char(0),'') , ' ', g.LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate,
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, ce.ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
 LEFT JOIN (
	SELECT PatientId,ExitReason,ExitDate,TransferOutfacility,CreatedBy FROM (
		SELECT PatientId,l.Name AS ExitReason,ExitDate,TransferOutfacility,CreatedBy,ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM patientcareending ce INNER JOIN LookupItem l ON
		l.Id = ce.ExitReason
		WHERE ce.DeleteFlag = 0 -- AND ce.ExitDate < @startDate
	) ce WHERE rowNum = 1
 ) ce ON g.Id = ce.PatientId
LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
LEFT JOIN (
	select PatientId,MCHNumber,MCHEnrollmentDate FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber,CAST(ps.StartDate AS DATE) as MCHEnrollmentDate FROM mst_Patient M 
		INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk 
		LEFT JOIN Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk INNER JOIN mst_module modu ON ps.ModuleId = modu.ModuleID 
		WHERE  modu.ModuleId = 15 AND MCHID IS NOT NULL
	) ti WHERE rowNUm = 1 AND MCHEnrollmentDate <= @endDate AND MCHEnrollmentDate >= @startDate
) mch ON mch.PatientID = g.Id
WHERE g.Sex = 52
 ),
mch_cte AS (
	select PatientId,MCHNumber,MCHEnrollmentDate FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber,CAST(ps.StartDate AS DATE) as MCHEnrollmentDate FROM mst_Patient M 
		INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk 
		LEFT JOIN Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk INNER JOIN mst_module modu ON ps.ModuleId = modu.ModuleID 
		WHERE  modu.ModuleId = 15 AND MCHID IS NOT NULL
	) ti WHERE rowNUm = 1 AND MCHEnrollmentDate <= @endDate AND MCHEnrollmentDate >= @startDate
)
/*
SELECT DISTINCT a.PatientPk, a.EnrollmentNumber, Regimen, ROW_NUMBER() OVER(PARTITION BY a.PatientId, Regimen ORDER BY RegimenStartDate) rown, CAST(t.RegimenStartDate AS DATE) AS RegimenDate
INTO #tmpDrugHistory
FROM PatientTreatmentTrackerViewD4T t
INNER JOIN all_Patients_cte a ON t.PatientId = a.PatientId
INNER JOIN mch_cte mch ON mch.PatientID = a.PatientID
WHERE Regimen IS NOT NULL-- AND TreatmentStatus <> 'Continue Current Treatment'
AND RegimenStartDate IS NOT NULL
AND Regimen <> 'Unknown'
--AND a.Sex = 'F' 
AND a.currentAge BETWEEN 15 AND 50 

SELECT Patientpk,Regimen,RegimenDate, CASE (ROW_NUMBER() OVER(PARTITION BY PatientPk ORDER BY RegimenDate)) WHEN 1 THEN 'ARTStart' ELSE 'ARTSwitch/Substitution' END AS Reason FROM #tmpDrugHistory WHERE --PatientPk = 10183 AND 
rown = 1 ORDEr BY PatientPk, RegimenDate
*/

SELECT DISTINCT a.PatientPk, a.EnrollmentNumber, v.VL, ROW_NUMBER() OVER(PARTITION BY a.PatientId ORDER BY v.Vldate) rown, v.VLDate, v.Reasons
INTO #tmpVLHistory
FROM (SELECT PatientId,CAST(SampleDate AS DATE) VLDate, Reasons, ResultValues AS VL FROM PatientLabtracker WHERE LabName = 'Viral Load' AND Results = 'Complete') v
INNER JOIN all_Patients_cte a ON v.PatientId = a.PatientId
INNER JOIN mch_cte mch ON mch.PatientID = a.PatientID
WHERE a.currentAge BETWEEN 15 AND 50 



SELECT PatientPk,VLDate,Vl,Reasons, ROW_NUMBER() OVER (PARTITION BY PatientPk ORDER BY VLDate) AS VLNumber FROM #tmpVLHistory
ORDER BY PatientPk, VLDate


select * from gcPatientView WHERE ptn_pk = 335
