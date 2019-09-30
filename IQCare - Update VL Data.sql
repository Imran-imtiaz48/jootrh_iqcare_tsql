set rowcount 0

/*
	Auto prescribe and dispense CTX to patients who's last visits don't have a CTX prescription
*/

DECLARE @ptnPk as INT
DECLARE @locationId as INT = 754
DECLARE @visitDate as DATE
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

declare @ageAtLastVisit AS int

declare @cccNumber AS nvarchar(100)

declare @sex AS nvarchar(6)
declare @fullcccNumber AS nvarchar(15)
declare @firstName AS nvarchar(max)
declare @rc AS int

declare @i as Int = 10

BEGIN TRY 
	DROP table #tmpUpdateVL
END TRY
BEGIN CATCH
END CATCH

BEGIN TRY
    BEGIN TRANSACTION
		exec pr_OpenDecryptedSession
		SELECT
			PatientId as FullCCCNumber,
			CASE WHEN LEN(PatientId) = 11 AND PatientId LIKE '13939%' THEN --To match values like 13939-26222
				(SUBSTRING(PatientId,CHARINDEX('-', PatientId)+1, LEN(PatientId)))  
			ELSE 
				(SUBSTRING(PatientId,1, (LEN(PatientId) - CHARINDEX('-', REVERSE(PatientId))))) 
			END  
			as cccNumber,
			LastVLDate, LastVLValue, d.Sex, d.Name
		INTO #tmpUpdateVL
		FROM [dbo].[IQCareLineList] d WHERE Updated = 0 AND lastVLDate IS NOT NULL AND PatientId IS NOT NULL --AND PatientId IN ('13939-00795') --IS NOT NULL

		 Select * from #tmpUpdateVL

		SELECT @cccNumber = min(CCCNumber) FROM #tmpUpdateVL

		SELECT @sex = (CASE WHEN sex = 'M' THEN 51 ELSE 52 END), @fullCCCNumber = FullCCCNumber, @firstName = (SUBSTRING([name],0,CHARINDEX(' ', [name])))   FROM #tmpUpdateVL  WHERE cccNumber = @cccNumber

		set rowcount 0

		WHILE @cccNumber IS NOT NULL
		BEGIN
			-- Get Patient Id 
			SELECT 
				@PatientId = id, @ptnpk = ptn_pk , @ageAtLastVisit = DATEDIFF(YEAR,p.DateOfBirth, '2017-03-31')
			FROM gcPatientView p
			WHERE EnrollmentNumber = @fullcccNumber

			set @rc = @@ROWCOUNT
			if @rc = 0
			BEGIN
				SELECT 
					@PatientId = id, @ptnpk = ptn_pk , @ageAtLastVisit = DATEDIFF(YEAR,p.DateOfBirth, '2017-03-31')
				FROM gcPatientView p
				WHERE EnrollmentNumber LIKE CONCAT('%',@cccNumber,'%') AND p.Sex = @sex AND CONCAT(Firstname,' ',MiddleName,'',LastName) LIKE CONCAT('%',@firstName,'%')
			END

			if @rc = 1 OR @@ROWCOUNT = 1
			BEGIN		
				-- Get Visit Date
				SELECT @visitDate = LastVLDate FROM #tmpUpdateVL WHERE cccNumber = @cccNumber

				if @visitDate IS NOT NULL 
				BEGIN
					-- Get Visit. If not existing, create a new one
					SELECT 
							@PatientMasterVisitID = Id, @UserID = CreatedBy
					FROM PatientMasterVisit 
					WHERE 
						PatientId = @PatientId AND ((DATEDIFF (hour, ISNULL([Start],VisitDate), @visitDate)) <= 24)

					if	@@ROWCOUNT = 0 
					BEGIN
						INSERT [dbo].[PatientMasterVisit]([PatientId], [ServiceId], [Start], [End], [VisitScheduled], [VisitBy], [VisitType], [VisitDate], [Active], [Status], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@PatientId, 1, @visitDate, @visitDate, NULL, NULL, NULL, @visitDate, 0, 1, NULL, GETDATE(), 1, 0)
			
						SET @PatientMasterVisitID = IDENT_CURRENT('PatientMasterVisit')
						SET @UserID = 1

					END

					--xxxxxxxxxxxxxxxxxx -- Begin, Repeat above for ord_visit table
					SELECT 
							@visitId = Visit_Id, @UserID = CreatedBy
					FROM ord_Visit 
					WHERE 
						Ptn_Pk = @ptnpk AND ((DATEDIFF (hour, ISNULL(VisitDate,CreateDate), @visitDate)) <= 24)

					if	@@ROWCOUNT = 0 
					BEGIN
						exec sp_executesql N'INSERT [dbo].[ord_Visit]
							([Ptn_Pk], [LocationID], [VisitDate], [VisitType], [DataQuality], [UserID], [TypeofVisit], [OrderedBy], [ReportedBy], [Signature], [ModuleId], [old_signature_employee_id], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@0, @1, @2, @3, 1, @4, @5, @6, @7, @8, @9, @10, NULL, @11, @12, @13)
						',N'@0 int,@1 int,@2 datetime2(7),@3 int,@4 int,@5 int,@6 int,@7 int,@8 int,@9 int,@10 int,@11 datetime2(7),@12 int,@13 bit',
						@0=@ptnPk,@1=@locationId,@2=@visitDate,@3=@visitType,@4=@userId,@5=@typeOfVisit,@6=0,@7=0,@8=0,@9=@moduleId,@10=0,@11=@createDate,@12=@userId,@13=0
			
						SET @visitId = IDENT_CURRENT('ord_Visit')
						SET @UserID = 1

					END
					--xxxxxxxxxxxxxxxxxxxxx -- End, Repeat above for ord_visit table

					SELECT 
						@resultDate=lastVLDate,
						@resultValues = LastVLValue 
					FROM #tmpUpdateVL WHERE cccNumber = @cccNumber
					
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

						UPDATE IQCareLineList SET Updated = 1, DateUpdated = getdate() WHERE PatientId = @fullcccNumber

					END
					ELSE
					BEGIN
						UPDATE IQCareLineList SET Updated = 2, DateUpdated = getdate() WHERE PatientId = @fullcccNumber
					END

				END			

			END
			ELSE
			BEGIN
				UPDATE IQCareLineList SET Updated = 4, DateUpdated = getdate() WHERE PatientId = @fullcccNumber
			END
	
			DELETE FROM #tmpUpdateVL WHERE CccNumber = @cccNumber 
			SELECT @cccNumber = min(CCCNumber) FROM #tmpUpdateVL
			SELECT @sex = (CASE WHEN sex = 'M' THEN 51 ELSE 52 END), @fullCCCNumber = FullCCCNumber, @firstName = (SUBSTRING([name],0,CHARINDEX(' ', [name])))   FROM #tmpUpdateVL  WHERE cccNumber = @cccNumber
		END
	    
		COMMIT TRAN -- Transaction Success!
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
        DECLARE @ErrorState INT = ERROR_STATE()

    -- Use RAISERROR inside the CATCH block to return error  
    -- information about the original error that caused  
    -- execution to jump to the CATCH block.  
    RAISERROR (@ErrorMessage, -- Message text.  
               @ErrorSeverity, -- Severity.  
               @ErrorState -- State.  
               );
END CATCH
