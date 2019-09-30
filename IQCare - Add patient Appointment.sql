-- Add Appointment
DECLARE @VisitDate AS DATE = '2019-09-02'
-- DECLARE @TCADate AS DATE = DATEADD(D, 14, @VisitDate)
DECLARE @TCADate AS DATE = '2019-10-01'

DECLARE @PatientId AS INT = 12380

--select * from gcPatientView WHERE EnrollmentNumber = '13939-24727'

--select * from PatientMasterVisit WHERE PatientId = 2964 ORDER BY CreateDate DESC

DECLARE @description AS NVARCHAR(150)

SET @description = 'Data cleaning entry'
--SET @description = 'Refilled Outside JOOTRH'
--SET @description = 'Refilled'


-- select * from gcPatientView WHERE EnrollmentNumber LIKE '%13939-20562%'
--set @TCADate = '2019-05-22'
DECLARE @PatientMasterVisitId AS INT, @VisitId AS INT, @UserId AS INT, @EncounterId INT, @dcModelId INT

IF @VisitDate >= @TCADate
BEGIN
	PRINT 'Invalid Dates provided'
	RETURN
END

IF DATENAME(DW, @TCADate) = 'Saturday' OR DATENAME(DW, @TCADate) = 'Sunday'
BEGIN
	PRINT 'Weekend TCA'
	return
END

IF DATENAME(DW, @VisitDate) = 'Saturday' OR DATENAME(DW, @VisitDate) = 'Sunday'
BEGIN
	PRINT 'Weekend Visit date'
	return
END


SELECT TOP 1
		@PatientMasterVisitID = v.Id, @UserID = v.CreatedBy, @VisitDate = CAST(v.VisitDate AS DATE)
FROM PatientMasterVisit v
INNER JOIN lnk_UserGroup lg ON v.CreatedBy = lg.UserID
WHERE 
	PatientId = @patientId AND (ABS(DATEDIFF (DAY, ISNULL(VisitDate,[Start]), @VisitDate)) <= 5)
	AND  (lg.GroupID = 5 or lg.GroupID = 7) -- Encounters by nurses and clinicians

IF	@@ROWCOUNT = 0 
	exec sp_getVisit @VisitDate, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT

IF EXISTS (SELECT TOP 1 id FROM PatientAppointment WHERE PatientId = @PatientId AND PatientMasterVisitId = @patientMasterVisitId)
	UPDATE PatientAppointment SET AppointmentDate = @TCADate WHERE PatientId = @patientId and PatientMasterVisitId = @patientMasterVisitId 
ELSE
BEGIN
		SET @dcModelId = (SELECT ISNULL(DifferentiatedCareId,254)  FROM (
						SELECT a.PatientId, a.DifferentiatedCareId, ROW_NUMBER() OVER (PARTITION BY a.PatientId ORDER BY v.VisitDate DESC) rown
						FROM PatientAppointment a 
						INNER JOIN PAtientMasterVisit v ON v.PatientID = a.PatientId AND v.id = a.PatientMasterVisitId 
						WHERE a.PatientId = @PatientId AND v.VisitDate < @VisitDate
					) d WHERE d.rown = 1)
		INSERT [dbo].[PatientAppointment]
		([PatientMasterVisitId], [PatientId], [ServiceAreaId], [AppointmentDate], [ReasonId], [Description], [DifferentiatedCareId], [StatusId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
		VALUES 
		(@PatientMasterVisitId, @patientId, 255, @TCADate, 232, ISNULL(@description,'Data cleaning entry'), @dcModelId, 220, @VisitDate, NULL, getdate(), @userId, 0)

END
-- Create CCC encounter if it doesn't exist
DECLARE @encounterTypeId AS INT = 1482
IF @dcModelId = 254
BEGIN
	exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT
END

