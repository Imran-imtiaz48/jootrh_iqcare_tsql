-- Upload clean data
-- ============================================
-- Get Visit, if not existing then create one -- done
-- Update height, weight and BMI, if present
-- Update cd4 if present
-- update VL if present
-- Prescribe, if prescription is missing 
-- Add TCA, if not existing

set rowcount 0

DECLARE @ptnPk as INT
DECLARE @locationId as INT = 754
DECLARE @VisitDate as DATE
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
DECLARE @EncounterId as int
DECLARE @serviceAreaId as int = 205
DECLARE @resultDate as date

DECLARE @Period AS NVARCHAR(15) 
DECLARE @Height AS FLOAT
DECLARE @Weight AS FLOAT
DECLARE @VL AS INT
DECLARE @CD4 AS INT
DECLARE @Regimen AS NVARCHAR(15)
DECLARE @TCADate AS DATE

DECLARE @Id AS INT

declare @sex AS nvarchar(6)
declare @cccNumber AS nvarchar(15)
declare @firstName AS nvarchar(max)
declare @rc AS int

declare @datacleaningUser AS INT 

IF NOT EXISTS(SELECT * FROM mst_User WHERE UserName = 'DataCleaning')
	EXEC Pr_Admin_SaveNewUser_Constella 'Data', 'Cleaning', 'DataCleaning', 'datacleaning', NULL, NULL
SELECT @datacleaningUser = UserId FROM mst_User WHERE UserName = 'DataCleaning'

BEGIN TRY 
	DROP table #tmpMCH
END TRY
BEGIN CATCH
END CATCH

SET NOCOUNT ON

SELECT
d.id, PatientId, CCCNumber,Period, VisitDate, Height, Weight, VL, CD4, Regimen, TCADate	
INTO #tmpMCH
FROM [dbo].tmpImportStagingTable d WHERE ReadyForUpload = 1 ANd Updated = 0 AND id = 13004 -- AND PatientId = 4985 -- AND Updated = 0 -- AND [CCC Number] IN ('13939-24532') --IS NOT NULL
--select * from #tmpMCH
SELECT @id = min(id) FROM #tmpMCH

set rowcount 0

BEGIN TRY
	WHILE @id IS NOT NULL
	BEGIN				

			-- Get Visit Date
			SELECT @patientId = PatientId, @Period = Period, @CCCNUmber = CCCNumber, @VisitDate = VisitDate, @Height = Height, @Weight = Weight, @VL = VL, @CD4 = CD4, @Regimen = Regimen, @TCADate = TCADate FROM #tmpMCH WHERE id = @id

			SET @ptnPk = (SELECT  ptn_pk FROM patient WHERE id = @patientId)

			DECLARE @vVisitDate AS DATE
			SELECT TOP 1
					@PatientMasterVisitID = Id, @UserID = CreatedBy, @vVisitDate = ISNULL([Start],VisitDate)
			FROM PatientMasterVisit 
			WHERE 
				PatientId = @PatientId AND (ABS(DATEDIFF (DAY, ISNULL([Start],VisitDate), @VisitDate)) <= 5)

			if @@ROWCOUNT > 0
			BEGIN
				SET @VisitDate = @vVisitDate
			END

			exec sp_getVisit @visitDate, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @datacleaningUser OUT

			-- Update height, weight and BMI, if present
			if @Height IS NOT NULL AND @Weight IS NOT NULL
			BEGIN
				IF NOT EXISTS (SELECT * FROM PatientVitals WHERE PatientId = @patientId AND (PatientMasterVisitId = @patientMasterVisitId OR VisitDate = @VisitDate))
				BEGIN
					--BEGIN TRY
						DECLARE @bmi AS decimal(8, 2) = @weight / ((@height/100)*(@height/100))
						--print CONCAT('INSERT [dbo].[PatientVitals]([PatientId], [PatientMasterVisitId], [Temperature], [RespiratoryRate], [HeartRate], [Bpdiastolic], [BpSystolic], [Height], [Weight], [Muac], [SpO2], [BMI], [HeadCircumference], [BMIZ], [WeightForHeight], [WeightForAge], [VisitDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])',
						--'VALUES (',@PatientId,', ',@PatientMasterVisitId,' 0, 0, 0, 0, 0, @height, @weight, 0, 0, @bmi, 0, 0, 0, 0, @VisitDate, NULL, GETDATE(),', @datacleaningUser,' 0)')
						INSERT [dbo].[PatientVitals]([PatientId], [PatientMasterVisitId], [Temperature], [RespiratoryRate], [HeartRate], [Bpdiastolic], [BpSystolic], [Height], [Weight], [Muac], [SpO2], [BMI], [HeadCircumference], [BMIZ], [WeightForHeight], [WeightForAge], [VisitDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@PatientId, @PatientMasterVisitId, 0, 0, 0, 0, 0, @height, @weight, 0, 0, @bmi, 0, 0, 0, 0, @VisitDate, NULL, GETDATE(), @datacleaningUser, 0)

						-- Create Triage encounter
						SET @encounterTypeId = 1502
						exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT
					--END TRY
					--BEGIN CATCH
					--	print 'error'
					--END CATCH
				END
			END
			-- Update VL if present
			IF @vl IS NOT NULL
			BEGIN
					SET @labTestId = 3
					SET @userId = @datacleaningUser
					SET @createDate = GETDATE()
					SET @resultValues = @vl
					SET @encounterTypeId = 1503-- LAB

					IF NOT EXISTS (
						SELECT        o.Id, ot.LabTestId
						FROM            dtl_LabOrderTest AS ot INNER JOIN
													ord_LabOrder AS o ON ot.LabOrderId = o.Id
						WHERE        (o.PatientId = @PatientId) AND (o.Ptn_Pk = @PtnPk) AND (o.OrderDate = @VisitDate) AND (ot.LabTestId = @LabTestId))
					BEGIN

						exec sp_executesql N'INSERT [dbo].[ord_LabOrder]([PatientId], [Ptn_pk], [OrderDate], [PreClinicLabDate], [ClinicalOrderNotes], [OrderStatus], [UserId], [LocationId], [VisitId], [PatientMasterVisitId], [ModuleId], [OrderNumber], [OrderedBy], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, NULL, @3, @4, @5, @6, @7, @8, @9, NULL, @10, NULL, @11, @12, @13)
						',N'@0 int,@1 int,@2 datetime2(7),@3 nvarchar(max) ,@4 nvarchar(max) ,@5 int,@6 int,@7 int,@8 int,@9 int,@10 int,@11 datetime2(7),@12 int,@13 bit',
						@0=@patientId,@1=@ptnPk,@2=@visitDate,@3=N'Added by system',@4=N'Complete',@5=@userId,@6=@locationId,@7=@visitId,@8=@patientMasterVisitId,@9=@moduleId,@10=@userId,@11=@createDate,@12=@userId,@13=0

						SELECT @labOrderId = IDENT_CURRENT('ord_LabOrder')

						exec sp_executesql N'INSERT [dbo].[dtl_LabOrderTest]([LabOrderId], [LabTestId], [TestNotes], [IsParent], [ParentTestId], [ResultNotes], [ResultBy], [ResultDate], [ResultStatus], [UserId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, NULL, @11, @9, @10, @12, @4, @5, NULL, @6, @7, @8)
						',N'@0 int,@1 int,@2 nvarchar(max) ,@3 bit,@4 int,@5 datetime2(7),@6 datetime2(7),@7 int,@8 bit,@9 int,@10 datetime2(7),@11 nvarchar(50),@12 nvarchar(50)',
						@0=@labOrderId,@1=@labTestId,@2=N'Added by system',@3=0,@4=@userId,@5=@createDate,@6=@createDate,@7=@userId,@8=0,@9=@userId,@10=@visitDate,@11='Group lab tests complete',@12='Received'

						SELECT @labOrderTestId = IDENT_CURRENT('dtl_LabOrderTest')

						exec sp_executesql N'INSERT [dbo].[PatientLabTracker]([PatientId], [LabName], [PatientMasterVisitId], [SampleDate], [Reasons], [Results], [LabOrderId], [LabTestId], [FacilityId], [ResultValues], [ResultTexts], [LabOrderTestId], [ResultUnits], [ResultOptions], [ResultDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, NULL, @10, NULL, NULL, NULL, NULL, @11, @12, @13)
						',N'@0 int,@1 nvarchar(max) ,@2 int,@3 datetime2(7),@4 nvarchar(max) ,@5 nvarchar(max) ,@6 int,@7 int,@8 int,@9 decimal(18,2),@10 int,@11 datetime2(7),@12 int,@13 bit',
						@0=@patientId,@1=N'Viral Load',@2=@patientMasterVisitId,@3=@visitDate,@4=N'Routine',@5=N'Complete',@6=@labOrderId,@7=@labTestId,@8=@locationId,@9=@resultValues,@10=@labOrderTestId,@11=@createDate,@12=@userId,@13=0

						exec sp_executesql N'INSERT [dbo].[PatientEncounter]([PatientId], [EncounterTypeId], [Status], [PatientMasterVisitId], [EncounterStartTime], [EncounterEndTime], [ServiceAreaId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @4, @5, @6, NULL, @7, @8, @9)
						',N'@0 int,@1 int,@2 int,@3 int,@4 datetime2(7),@5 datetime2(7),@6 int,@7 datetime2(7),@8 int,@9 bit',
						@0=@patientId,@1=@encounterTypeId,@2=0,@3=@patientMasterVisitId,@4=@createDate,@5=@createDate,@6=@serviceAreaId,@7=@createDate,@8=@userId,@9=0

						exec sp_executesql N'INSERT [dbo].[dtl_LabOrderTestResult]([LabOrderId], [LabTestId], [LabOrderTestId], [ParameterId], [ResultValue], [ResultText], [ResultOptionId], [ResultOption], [ResultUnit], [ResultUnitId], [ResultConfigId], [Undetectable], [DetectionLimit], [UserId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @9, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, @4, @5, NULL, @6, @7, @8)
						',N'@0 int,@1 int,@2 int,@3 int,@4 int,@5 datetime2(7),@6 datetime2(7),@7 int,@8 bit,@9 int',
						@0=@labOrderId,@1=@labTestId,@2=@labOrderTestId,@3=3,@4=1,@5=@createDate,@6=@createDate,@7=@userId,@8=0,@9=@resultValues


						-- Create lab encounter
						exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT

					END
			
			END

			-- Update CD4 if present
			IF @cd4 IS NOT NULL AND @cd4 > 0
			BEGIN
					SET @labTestId = 1
					SET @userId = @datacleaningUser
					SET @createDate = GETDATE()
					SET @resultValues = @cd4
					SET @encounterTypeId = 1503-- LAB

					IF NOT EXISTS (
						SELECT        o.Id, ot.LabTestId
						FROM            dtl_LabOrderTest AS ot INNER JOIN
													ord_LabOrder AS o ON ot.LabOrderId = o.Id
						WHERE        (o.PatientId = @PatientId) AND (o.Ptn_Pk = @PtnPk) AND (o.OrderDate = @VisitDate) AND (ot.LabTestId = @LabTestId))
					BEGIN

						exec sp_executesql N'INSERT [dbo].[ord_LabOrder]([PatientId], [Ptn_pk], [OrderDate], [PreClinicLabDate], [ClinicalOrderNotes], [OrderStatus], [UserId], [LocationId], [VisitId], [PatientMasterVisitId], [ModuleId], [OrderNumber], [OrderedBy], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, NULL, @3, @4, @5, @6, @7, @8, @9, NULL, @10, NULL, @11, @12, @13)
						',N'@0 int,@1 int,@2 datetime2(7),@3 nvarchar(max) ,@4 nvarchar(max) ,@5 int,@6 int,@7 int,@8 int,@9 int,@10 int,@11 datetime2(7),@12 int,@13 bit',
						@0=@patientId,@1=@ptnPk,@2=@visitDate,@3=N'Added by system',@4=N'Complete',@5=@userId,@6=@locationId,@7=@visitId,@8=@patientMasterVisitId,@9=@moduleId,@10=@userId,@11=@createDate,@12=@userId,@13=0

						SELECT @labOrderId = IDENT_CURRENT('ord_LabOrder')

						exec sp_executesql N'INSERT [dbo].[dtl_LabOrderTest]([LabOrderId], [LabTestId], [TestNotes], [IsParent], [ParentTestId], [ResultNotes], [ResultBy], [ResultDate], [ResultStatus], [UserId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, NULL, @11, @9, @10, @12, @4, @5, NULL, @6, @7, @8)
						',N'@0 int,@1 int,@2 nvarchar(max) ,@3 bit,@4 int,@5 datetime2(7),@6 datetime2(7),@7 int,@8 bit,@9 int,@10 datetime2(7),@11 nvarchar(50),@12 nvarchar(50)',
						@0=@labOrderId,@1=@labTestId,@2=N'Added by system',@3=0,@4=@userId,@5=@createDate,@6=@createDate,@7=@userId,@8=0,@9=@userId,@10=@visitDate,@11='Group lab tests complete',@12='Received'

						SELECT @labOrderTestId = IDENT_CURRENT('dtl_LabOrderTest')

						exec sp_executesql N'INSERT [dbo].[PatientLabTracker]([PatientId], [LabName], [PatientMasterVisitId], [SampleDate], [Reasons], [Results], [LabOrderId], [LabTestId], [FacilityId], [ResultValues], [ResultTexts], [LabOrderTestId], [ResultUnits], [ResultOptions], [ResultDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, NULL, @10, NULL, NULL, NULL, NULL, @11, @12, @13)
						',N'@0 int,@1 nvarchar(max) ,@2 int,@3 datetime2(7),@4 nvarchar(max) ,@5 nvarchar(max) ,@6 int,@7 int,@8 int,@9 decimal(18,2),@10 int,@11 datetime2(7),@12 int,@13 bit',
						@0=@patientId,@1=N'Viral Load',@2=@patientMasterVisitId,@3=@visitDate,@4=N'Routine',@5=N'Complete',@6=@labOrderId,@7=@labTestId,@8=@locationId,@9=@resultValues,@10=@labOrderTestId,@11=@createDate,@12=@userId,@13=0

						exec sp_executesql N'INSERT [dbo].[PatientEncounter]([PatientId], [EncounterTypeId], [Status], [PatientMasterVisitId], [EncounterStartTime], [EncounterEndTime], [ServiceAreaId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @4, @5, @6, NULL, @7, @8, @9)
						',N'@0 int,@1 int,@2 int,@3 int,@4 datetime2(7),@5 datetime2(7),@6 int,@7 datetime2(7),@8 int,@9 bit',
						@0=@patientId,@1=@encounterTypeId,@2=0,@3=@patientMasterVisitId,@4=@createDate,@5=@createDate,@6=@serviceAreaId,@7=@createDate,@8=@userId,@9=0

						exec sp_executesql N'INSERT [dbo].[dtl_LabOrderTestResult]([LabOrderId], [LabTestId], [LabOrderTestId], [ParameterId], [ResultValue], [ResultText], [ResultOptionId], [ResultOption], [ResultUnit], [ResultUnitId], [ResultConfigId], [Undetectable], [DetectionLimit], [UserId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, @9, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, @4, @5, NULL, @6, @7, @8)
						',N'@0 int,@1 int,@2 int,@3 int,@4 int,@5 datetime2(7),@6 datetime2(7),@7 int,@8 bit,@9 int',
						@0=@labOrderId,@1=@labTestId,@2=@labOrderTestId,@3=3,@4=1,@5=@createDate,@6=@createDate,@7=@userId,@8=0,@9=@resultValues

						-- Create lab encounter
						exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT

					END
			
			END

			-- Add TCA, if not existing
			IF (@TCADate IS NOT NULL)
			BEGIN
				IF NOT EXISTS (SELECT 	Id 	FROM PatientAppointment WHERE PatientId = @patientId AND AppointmentDate = @TCADate)
				BEGIN
					INSERT [dbo].[PatientAppointment]
					([PatientMasterVisitId], [PatientId], [ServiceAreaId], [AppointmentDate], [ReasonId], [Description], [DifferentiatedCareId], [StatusId], [StatusDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
					VALUES 
					(@PatientMasterVisitId, @patientId, 255, @TCADate, 232, 'Data cleaning entry', 254, 220, @visitDate, NULL, getdate(), @datacleaningUser, 0)

					-- Create CCC encounter
					SET @encounterTypeId = 1482
					exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT
				END					
			END
			/*
			-- Prescribe, if prescription is missing 
			IF NOT EXISTS (SELECT * FROM ord_PatientPharmacyOrder WHERE (PatientId = @patientId OR Ptn_pk = @ptnPk) AND (PatientMasterVisitId = @patientMasterVisitId OR VisitID = @visitId OR DispensedByDate = @VisitDate) )
			BEGIN
				-- GET regimen id. GEt component drugs from an exisitng regimen and use them

				exec sp_SaveUpdatePharmacy_GreenCard 
				@PatientMasterVisitID=N'55067',
				@PatientId=N'11474',
				@LocationID=N'754',
				@OrderedBy=N'1',
				@UserID=N'1',
				@RegimenType=N'',
				@DispensedBy=N'1',
				@RegimenLine=N'215',
				@ModuleID=N'',
				@TreatmentProgram=N'222',
				@PeriodTaken=N'0',
				@TreatmentPlan=N'523',
				@TreatmentPlanReason=N'0',
				@Regimen=N'133',
				@PrescribedDate=N'05-Feb-2018',
				@DispensedDate=N'05-Feb-2018'

				exec sp_DeletePharmacyPrescription_GreenCard 
				@ptn_pharmacy_pk=N'166853'

				exec sp_SaveUpdatePharmacyPrescription_GreenCard 
				@ptn_pharmacy_pk=N'166853',
				@DrugId=N'1022',
				@BatchId=N'0',
				@FreqId=N'1',
				@Dose=N'1',
				@Duration=N'15',
				@qtyPres=N'15',
				@qtyDisp=N'15',
				@prophylaxis=N'0',
				@pmscm=N'0',
				@UserID=N'1'

				-- Create pharmacy encounter
				SET encounterTypeId = 1504
				exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT

			END
			*/select * from tmpImportStagingTable
			UPDATE tmpImportStagingTable SET Updated = 1 WHERE id = @Id

			DELETE FROM #tmpMCH WHERE Id = @Id 
			SELECT @Id = min(Id) FROM #tmpMCH
 
	END
END TRY
BEGIN CATCH
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
	print CONCAT('Error: PID ',  @PatientId,  ' Period: ',  @Period,': ',  ' ID: ',  @Id,': ', @ErrorMessage)

END CATCH

-- select * from tmpImportStagingTable WHERE CCCNumber = '13939-20440'
select * from tmpImportStagingTable WHERE id = 13004
--update tmpImportStagingTable SET Updated = 0 WHERE id = 13004
-- ALTER TABLE tmpImportStagingTable ADD updated SMALLINT NOT NULL DEFAULT 0

select * from PatientLabTracker WHERE patientId = 4985

select * from gcPatientView WHERE EnrollmentNumber LIKE '%13939-21394%'

select * from PatientTreatmentTrackerViewD4T WHERE PatientId = 522

select * from ARVTreatmentTracker WHERE PatientMasterVisitId = 94830

 
update ARVTreatmentTracker SET Regimenid=137, RegimenLineId = 215 WHERE PatientMasterVisitId = 94830
