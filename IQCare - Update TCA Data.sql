set rowcount 0

DECLARE @ptnPk as INT
DECLARE @locationId as INT = 754
DECLARE @visitDate as DATE
DECLARE @appointmentDate as DATE
DECLARE @visitType as INT = 6
DECLARE @userId as INT = 1
DECLARE @typeOfVisit as INT = 70
DECLARE @moduleId as INT = 203
DECLARE @createDate as DATE = getdate()
DECLARE @patientId as INT
DECLARE @visitId as INT
DECLARE @patientMasterVisitId as INT
DECLARE @labOrderId as int
DECLARE @labTestId as int = 3
DECLARE @resultValues as int
DECLARE @labOrderTestId as int
DECLARE @encounterTypeId as int = 1503
DECLARE @serviceAreaId as int = 205
DECLARE @resultDate as date

DECLARE @id as int

declare @sex AS nvarchar(6)
declare @fullcccNumber AS nvarchar(15)
declare @firstName AS nvarchar(max)
declare @rc AS int

BEGIN TRY 
	DROP table #tmpTCA
END TRY
BEGIN CATCH
END CATCH

SELECT
Id, CCCNumber AS PatientId,MatchedTCA as AppointmentDate,LastVisitDate	
INTO #tmpTCA
FROM [dbo].[OutlookTCA] d WHERE Updated = 0 AND ValidTCA = 'Yes' AND MatchedTCA IS NOT NULL --AND PatientId IN ('13939-00795') --IS NOT NULL

select * from #tmpTCA
SELECT @id = min(id) FROM #tmpTCA

set rowcount 0

WHILE @id IS NOT NULL
BEGIN				

		-- Get Visit Date
		SELECT @visitDate = LastVisitDate, @appointmentDate = AppointmentDate FROM #tmpTCA WHERE id = @id

		SELECT 
				@PatientMasterVisitID = Id, @UserID = CreatedBy
		FROM PatientMasterVisit 
		WHERE 
			PatientId = @Id AND ((DATEDIFF (hour, ISNULL([Start],VisitDate), @visitDate)) <= 24)

		if	@@ROWCOUNT = 0 
		BEGIN
			INSERT [dbo].[PatientMasterVisit]([PatientId], [ServiceId], [Start], [End], [VisitScheduled], [VisitBy], [VisitType], [VisitDate], [Active], [Status], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
			VALUES (@Id, 1, @visitDate, @visitDate, NULL, NULL, NULL, @visitDate, 0, 1, NULL, GETDATE(), 1, 0)
		
			SET @PatientMasterVisitID = IDENT_CURRENT('PatientMasterVisit')
			SET @UserID = 1
		END

		SELECT 
				Id
		FROM PatientAppointment
		WHERE 
			PatientId = @Id AND AppointmentDate = @appointmentDate
					
		if	@@ROWCOUNT = 0 
		BEGIN
			INSERT [dbo].[PatientAppointment]
			([PatientMasterVisitId], [PatientId], [ServiceAreaId], [AppointmentDate], [ReasonId], [Description], [DifferentiatedCareId], [StatusId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
			VALUES 
			(@PatientMasterVisitId, @Id, 255, @appointmentDate, 232, 'Retrospective entry', 254, 220, @visitDate, NULL, getdate(), 1, 0)
		END

		UPDATE OutlookTCA SET Updated = 1 WHERE ID = @id

		DELETE FROM #tmpTCA WHERE Id = @Id 
		SELECT @Id = min(Id) FROM #tmpTCA
END
