-- Get PAMA Data

/**
 Define CTEs for:
 1. Getting Child data
 2. Getting Mother data - Consider parent of gender female
 3. Getting father data - consider parent of gender male
 4. Merge the data in a cte that captures relaevant data for Parent 1 and Parent 2
*/
exec pr_OpenDecryptedSession
GO

DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate ='2019-06-30';
set @endDate = GetDate();
--set @endDate = '2019-06-30';

;WITH all_Patients_cte as (
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
		CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM PatientAppointment X
	 WHERE AppointmentDate > @endDate 
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
-- WHERE g.PatientStatus = 'Death'
 ),

 vl_results_cte AS (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VLDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 3) AND SAmpleDate <= @endDate
	) vlr WHERE RowNum = 1 
 ),

 child_cte AS (
	SELECT 
		a.PatientID as ChildId, a.EnrollmentNumber AS ChildCCCNumber, a.PatientName as ChildName,a.Sex AS ChildSex, a.currentAge AS ChildAge, a.NextAppointmentDate as ChildTCADate, vl.VLResults as ChildLastVL, vl.VLDate as ChildLastVLDate,
		a.PhoneNumber, a.ContactName as [Contact's Name], a.ContactPhoneNumber AS [Contact's phone number],
		CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
			WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
			WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
			WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
			WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
			ELSE a.PatientStatus 
		END as ChildStatus
	FROM all_patients_cte a 
	LEFT JOIN vl_results_cte vl ON a.PatientID = vl.patientId
	WHERE 
		a.currentAge BETWEEN 0 AND 14 
		AND a.PatientStatus = 'Active'
		AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90
 ),

 parents_cte AS (
	SELECT pr.*, ROW_NUMBER() OVER (PARTITION BY pr.ChildId ORDER BY pr.relation) AS rown FROM (
		SELECT DISTINCT
			r.PatientId AS ChildId, a.PatientID as ParentId, a.EnrollmentNumber AS  ParentCCCNumber, a.PatientName as ParentName,a.Sex AS ParentSex, a.currentAge AS ParentAge, a.NextAppointmentDate as ParentTCADate, vl.VLResults as ParentLastVL, vl.VLDate as ParentLastVLDate,l.[name] AS Relation,
			CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
				WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
				WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
				WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
				WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
				ELSE a.PatientStatus 
			END as ParentStatus
		FROM PersonRelationship r 
		INNER JOIN all_Patients_cte a ON r.PersonId = a.PersonId
		INNER JOIN LookupItem l ON l.id = r.RelationshipTypeId AND r.DeleteFlag = 0
		LEFT JOIN vl_results_cte vl ON a.PatientID = vl.patientId
--		WHERE l.[Name] = 'Mother' OR l.[Name] = 'Father' OR l.[Name] = 'Parent' OR l.[Name] = 'Guardian'
	) pr
	INNER JOIN child_cte c ON c.ChildId = pr.ChildId
 )

-- select l.*,r.* from PersonRelationship r INNER JOIN LookupItem l ON l.Id = r.RelationshipTypeId  WHERE PatientId = 8613 AND r.DeleteFlag = 0
-- select * from PatientRelationshipView WHERE PatientId = 8613 
--select * from pama_linelist WHERE id = 8613
 --SELECT * FROM all_Patients_cte a  WHERE a.PatientID = 3527

-- return
 
 SELECT 
	c.*, 
	p1.ParentId as Parent1Id, p1.Relation AS Parent1Relation, p1.ParentCCCNumber as Parent1CCCNumber, p1.ParentName As Parent1Name, p1.ParentSex as Parent1Sex, p1.ParentAge AS Parent1Age, p1.ParentTCADate AS Parent1TCADate,p1.ParentLastVL AS Parent1LastVL, p1.ParentLastVLDate AS Parent1LastVLDate, p1.ParentStatus AS Parent1Status,
	p2.ParentId as Parent2Id, p2.Relation AS Parent2Relation, p2.ParentCCCNumber as Parent2CCCNumber, p2.ParentName As Parent2Name, p2.ParentSex as Parent2Sex, p2.ParentAge AS Parent2Age, p2.ParentTCADate AS Parent2TCADate,p2.ParentLastVL AS Parent2LastVL, p2.ParentLastVLDate AS Parent2LastVLDate, p2.ParentStatus AS Parent2Status
 FROM child_cte c LEFT JOIN
 parents_cte p1 ON c.ChildId = p1.ChildId AND p1.rown = 1 LEFT JOIN
 parents_cte p2 ON c.ChildId = p2.ChildId AND p2.rown = 2
 -- Unpaired
 -- WHERE p1.ChildId IS NULL
 --WHERE c.childId = 2148
