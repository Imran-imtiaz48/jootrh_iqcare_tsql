DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

BEGIN TRY
drop table #tmpV
END TRY
BEGIN CATCH
END CATCH

set @startDate ='2019-06-01';
set @endDate = GETDATE();
-- SET @endDate = DATEADD(D,-1,DATEADD(M,3,@startDate))

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber, EnrollmentNumber, UPPER(CONCAT(g.FirstName, ' ', REPLACE(g.MiddleName, char(0),'') , ' ', g.LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, ce.ExitReason--, CareEndingNotes
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
LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
LEFT JOIN (
		SELECT PatientId,
		CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM PatientAppointment X
	 WHERE AppointmentDate > @endDate 
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
-- WHERE g.PatientStatus = 'Death'
 )


 SELECT a.PatientID, a.EnrollmentNumber, CAST(a.NextAppointmentDate AS DATE) AS TCADATE FROM all_Patients_cte a
 --WHERE a.EnrollmentNumber = '13939-27282'

 --select * from PatientAppointment WHERE PatientId = 34191

 select * from PatientIdentifier WHERE IdentifierValue LIKE '%04371%'


 select * from gcPatientView WHERE EnrollmentNumber LIKE '%13939-25304%'


 select * from PatientScreening
  WHERE PatientId = 9123 AND ScreeningTypeId = 421 
  order by id desc

  
 select * from PatientScreening
  WHERE ScreeningTypeId = 421 
 
 select * from LookupItemView WHERE Mastername = 'CervicalCancerScreeningAssessment'
 select * from LookupItemView WHERE MasterId = 421

 select

