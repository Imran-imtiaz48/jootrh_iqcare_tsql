DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2019-06-01';
set @endDate = '2019-06-25';

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,UPPER(tp.ContactName) AS ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
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

providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
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

adolescent_review_cte AS (
	SELECT PatientId, ReviewDate, p.ProviderName AS ReviewedBy FROM PatientClinicalReviewChecklist r
	INNER JOIN providers_cte p ON p.UserID = r.CreatedBy
--		WHERE ReviewDate BETWEEN @StartDate and @endDate
)
/*
-- Adolescent reviews
SELECT 
	a.PatientID as ID, a.EnrollmentNumber as PatientId, a.PatientName,a.currentAge, a.Sex, ad.ReviewDate, ad.ReviewedBy 
FROM all_Patients_cte a 
INNER JOIN adolescent_review_cte ad ON a.PatientID = ad.PatientId
WHERE Reviewdate BETWEEN @startDate AND @endDate
*/

/*
-- Missing Adolescent clinical reviews
 SELECT --a.PatientID as id,
	a.EnrollmentNumber as PatientId,ti.TINumber,a.PatientName,a.sex, a.currentAge, 
	CAST(a.NextAppointmentDate AS DATE) as AppointmentDate,  
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) <= 30 THEN 'Active' 
		--WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) > 30 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus,
	a.PhoneNumber, a.ContactName, a.ContactPhoneNumber --,  cttx.Regimen
FROM all_Patients_cte a 
LEFT JOIN adolescent_review_cte ad ON a.PatientID = ad.PatientId
LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
WHERE a.PatientStatus = 'Active'
AND ad.PatientId IS NULL
AND a.currentAge BETWEEN 10 AND 24
AND DATEDIFF(D,a.NextAppointmentDate,@endDate) <= 30
ORDER BY a.NextAppointmentDate
 */


-- Duplicate Adolescent reviews
SELECT 
	a.PatientID as ID, a.EnrollmentNumber as PatientId, a.PatientName,a.currentAge, a.Sex, ad.ReviewDate, ad.ReviewedBy 
FROM all_Patients_cte a 
INNER JOIN adolescent_review_cte ad ON a.PatientID = ad.PatientId
WHERE Reviewdate BETWEEN @startDate AND @endDate


