IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_updateIPT') AND type= 'P')
	DROP PROCEDURE sp_updateIPT
GO

CREATE PROCEDURE sp_updateIPT
	@PatientId AS INT,
	@PatientMasterVisitId AS INT,
	@IptStartDate AS DATE,
	@Outcome AS INT,
	@OutcomeDate AS DATE,
	@userId AS INT,
	@ReasonForDiscontinuation AS NVARCHAR(100),
	@Success AS INT OUT
AS
BEGIN TRY
    BEGIN TRANSACTION
		DECLARE @OnIpt AS INT
		DECLARE @EverBeenOnIpt AS INT
		DECLARE @EncounterId AS INT
		DECLARE @ServiceId AS INT = 203
		DECLARE @Createdate AS DATE = GETDATE()
		DECLARE @VisitDate AS DATE

		SELECT @VisitDate = VisitDate FROM PatientMasterVisit WHERE Id = @PatientMasterVisitId 

		IF @Outcome > 0 AND @OutcomeDate IS NOT NULL
		BEGIN
			IF NOT EXISTS(SELECT PatientId FROM PatientIptOutcome WHERE PatientId = @PatientId)
				exec sp_executesql N'INSERT [dbo].[PatientIptOutcome]([PatientMasterVisitId], [PatientId], [IptEvent], [ReasonForDiscontinuation], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
				VALUES (@0, @1, @2, @3, NULL, @4, @5, @6)
				',N'@0 int,@1 int,@2 int,@3 nvarchar(max) ,@4 datetime2(7),@5 int,@6 bit',
				@0=@PatientMasterVisitId,@1=@PatientId,@2=@Outcome,@3=@ReasonForDiscontinuation,@4=@OutcomeDate,@5=@UserId,@6=0
		END

		IF @IptStartDate IS NOT NULL 
		BEGIN
			IF NOT EXISTS (SELECT * FROM PatientIptWorkup WHERE PatientMasterVisitId = @PatientMasterVisitId AND IptStartDate IS NOT NULL)
				exec sp_executesql N'INSERT [dbo].[PatientIptWorkup]
				([PatientMasterVisitId], [PatientId], [YellowColouredUrine], [Numbness], [YellownessOfEyes], [AbdominalTenderness], [LiverFunctionTests], [StartIpt], [IptStartDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
				VALUES (@0, @1, @2, @3, @4, @5, @6, @7, @8, NULL, @9, @10, @11)',
				N'@0 int,@1 int,@2 bit,@3 bit,@4 bit,@5 bit,@6 nvarchar(max) ,@7 bit,@8 datetime2(7),@9 datetime2(7),@10 int,@11 bit',
				@0=@PatientMasterVisitId,@1=@PatientId,@2=1,@3=1,@4=1,@5=1,@6=N'',@7=1,@8=@IptStartDate,@9=@CreateDate,@10=@UserId,@11=0
		END

		IF @IptStartDate IS NOT NULL 
		BEGIN
			IF @Outcome = 0 
			BEGIN
				SET @EverBeenOnIpt = 0
				SET @OnIpt = 1
			END
			ELSE
			BEGIN
				SET @EverBeenOnIpt = 1
				SET @OnIpt = 0
			END

			IF NOT EXISTS(SELECT * FROM PatientIcf WHERE PatientMasterVisitId = @PatientMasterVisitId)
				exec sp_executesql N'INSERT [dbo].[PatientIcf]([PatientMasterVisitId], [OnAntiTbDrugs], [OnIpt], [EverBeenOnIpt], [PatientId], [Cough], [Fever], [WeightLoss], [NightSweats], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
				VALUES (@0, @1, @2, @3, @4, @5, @6, @7, @8, NULL, @9, @10, @11)',
				N'@0 int,@1 bit,@2 bit,@3 bit,@4 int,@5 bit,@6 bit,@7 bit,@8 bit,@9 datetime2(7),@10 int,@11 bit',
				@0=@PatientMasterVisitId,@1=0,@2=@OnIpt,@3=@EverBeenOnIpt,@4=@PatientId,@5=0,@6=0,@7=0,@8=0,@9=@CreateDate,@10=@UserId,@11=0
		END

		exec sp_savePatientEncounterPresentingComplaints @PatientMasterVisitID=@PatientMasterVisitID,@PatientID=@PatientID,@ServiceID=@ServiceId,@VisitDate=@Visitdate,@VisitScheduled=N'0',@VisitBy=N'108',@anyPresentingComplaints=N'0',@ComplaintsNotes=N'',@TBScreening=N'29',@NutritionalStatus=N'1583',@userID=@UserId

		exec sp_getEncounter @PatientMasterVisitId, 1482, @PatientId, @UserId, @EncounterId OUT

		COMMIT TRAN -- Transaction Success!

		SET @Success = 1
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
		SET @Success = 0

    RAISERROR (@ErrorMessage, -- Message text.  
               @ErrorSeverity, -- Severity.  
               @ErrorState -- State.  
               );
END CATCH

