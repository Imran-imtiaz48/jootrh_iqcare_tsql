set rowcount 0

DECLARE @ptnPk as INT
DECLARE @locationId as INT = 754
DECLARE @CategorizationDate as DATE
-- DECLARE @VisitDate as DATE
DECLARE @categorization as INT
DECLARE @CategorizationId as INT
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

DECLARE @dcModel AS NVARCHAR(50)

DECLARE @id as int

declare @sex AS nvarchar(6)
declare @fullcccNumber AS nvarchar(15)
declare @firstName AS nvarchar(max)
declare @rc AS int

declare @datacleaningUser AS INT 

IF NOT EXISTS(SELECT * FROM mst_User WHERE UserName = 'DataCleaning')
	EXEC Pr_Admin_SaveNewUser_Constella 'Data', 'Cleaning', 'DataCleaning', 'datacleaning', NULL, NULL
SELECT @datacleaningUser = UserId FROM mst_User WHERE UserName = 'DataCleaning'

BEGIN TRY 
	DROP table #tmpDC
END TRY
BEGIN CATCH
END CATCH

SELECT
Id, PID, [CCC Number] AS PatientId,[Categorization date register] AS CategorizationDate, [Stable Model register] AS StableModel
INTO #tmpDC
FROM [dbo].DCCategorization d WHERE Updated = 0 -- AND [CCC Number] IN ('13939-24532') --IS NOT NULL

-- select * from #tmpDC
SELECT @id = min(id) FROM #tmpDC

set rowcount 0

WHILE @id IS NOT NULL
BEGIN				
		BEGIN TRY 
			-- Get Visit Date
			SELECT @patientId = PID, @CategorizationDate = CategorizationDate, @categorization = 1, @dcModel = StableModel FROM #tmpDC WHERE id = @id

			DECLARE @dcModelId AS INT 
			SET @dcModelId  = (SELECT TOP 1 ID FROM LookupItem WHERE Name = @dcModel)

			SELECT TOP 1
					@PatientMasterVisitID = v.Id, @UserID = v.CreatedBy, @CategorizationDate = v.VisitDate
			FROM PatientMasterVisit v
			INNER JOIN lnk_UserGroup lg ON v.CreatedBy = lg.UserID
			WHERE 
				PatientId = @patientId AND (ABS(DATEDIFF (DAY, ISNULL([Start],VisitDate), @CategorizationDate)) <= 5)
				AND  (lg.GroupID = 5 or lg.GroupID = 7) -- Encounters by nurses and clinicians

			IF	@@ROWCOUNT = 0 
				exec sp_getVisit @CategorizationDate, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT

			SELECT 
					@CategorizationId = Id
			FROM PatientCategorization
			WHERE 
				PatientId = @PatientId AND CAST(DateAssessed AS DATE) = CAST(@CategorizationDate AS DATE)
					
			if	@@ROWCOUNT = 0 
			BEGIN
				INSERT [dbo].[PatientCategorization]
				([PatientMasterVisitId], [PatientId], [Categorization], [DateAssessed], [DeleteFlag], [CreatedBy], [CreateDate])
				VALUES 
				(@PatientMasterVisitId, @PatientId, @categorization, @CategorizationDate, 0, @userId, GETDATE())
			END

			-- UPDATE PatientCategorization SET Categorization =  @categorization WHERE DateAssessed >= @CategorizationDate AND PatientId = @patientId
			UPDATE PatientCategorization SET Categorization =  @categorization WHERE PatientMasterVisitId = @patientMasterVisitId AND PatientId = @patientId AND Categorization <> @categorization

			--UPDATE PatientAppointment SET DifferentiatedCareId = (SELECT ID FROM LookupItem WHERE Name = 'Express Care') WHERE PatientId = @patientId and CreateDate >= @CategorizationDate

			IF EXISTS (SELECT TOP 1 id FROM PatientAppointment WHERE PatientId = @PatientId AND PatientMasterVisitId = @patientMasterVisitId)
				UPDATE PatientAppointment SET DifferentiatedCareId = @dcModelId WHERE PatientId = @patientId and PatientMasterVisitId = @patientMasterVisitId AND DifferentiatedCareId <> @dcModelId
			ELSE
			BEGIN
					DECLARE @TCADate AS DATE = DATEADD(M, 6, @CategorizationDate)
					DECLARE @EncounterId AS INT

					INSERT [dbo].[PatientAppointment]
					([PatientMasterVisitId], [PatientId], [ServiceAreaId], [AppointmentDate], [ReasonId], [Description], [DifferentiatedCareId], [StatusId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
					VALUES 
					(@PatientMasterVisitId, @patientId, 255, @TCADate, 232, 'Data cleaning entry', @dcModelId, 220, @CategorizationDate, NULL, getdate(), @userId, 0)

			END
			-- Create CCC encounter if it doesn't exist
			SET @encounterTypeId = 1482
			exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT
					
			UPDATE DCCategorization SET Updated = 1 WHERE ID = @id
		
			DELETE FROM #tmpDC WHERE Id = @Id 
		
		END TRY
		BEGIN CATCH
			DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			print CONCAT('Error: PID ',  @PatientId,  ' date: ',  @CategorizationDate,': ',  ' ID: ',': ', @ErrorMessage)
			DELETE FROM #tmpDC WHERE Id = @Id 
		END CATCH
		SELECT @Id = min(Id) FROM #tmpDC
END
