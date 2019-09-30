set rowcount 0

/*
	Auto prescribe and dispense CTX to patients who's last visits don't have a CTX prescription
*/

declare @ptn_pk AS int
declare @PatientMasterVisitID int = 0
declare @PatientId int = null
declare @LocationID int = null 
declare @OrderedBy int = null
declare @UserID int = null 
declare @RegimenType varchar(50) = null
declare @DispensedBy int=null 
declare @RegimenLine int = null
declare @PharmacyNotes varchar(200) = null
declare @ModuleID int = ''
declare @lastProvider int = null

declare @TreatmentProgram int = null
declare @PeriodTaken int = null

declare @TreatmentPlan int = null 
declare @TreatmentPlanReason int = null
declare @Regimen int = 0
declare @PrescribedDate varchar(50) = null
declare @DispensedDate varchar(50) = null 

declare @ptn_pharmacy_pk AS float
declare @drugId AS float
declare @ageAtLastVisit AS int
declare @daysToTCADate AS int
declare @qty AS int 

declare @cccNumber AS nvarchar(100)
declare @RegimenStartdate AS Date
declare @encounterType AS int

declare @sex AS nvarchar(6)
declare @fullcccNumber AS nvarchar(15)
declare @rc AS int

BEGIN TRY 
	DROP table #tmpUpdateRegimen
END TRY
BEGIN CATCH
END CATCH

BEGIN TRY
    BEGIN TRANSACTION
		SELECT
			CCCNumber as FullCCCNumber, NewCCCNumber as cccNumber, [Switch Date] as RegimenStartDate, [Current Regimen] as Regimen, d.Sex
		INTO #tmpUpdateRegimen
		FROM DTGData d WHERE Updated = 0 -- AND NewCccNumber IN ('01075','06058','09105') --IS NOT NULL

		-- Select * from #tmpUpdateRegimen

		SELECT @cccNumber = min(CCCNumber) FROM #tmpUpdateRegimen

		SELECT @sex = (CASE WHEN sex = 'MALE' THEN 51 ELSE 52 END), @fullCCCNumber = FullCCCNumber FROM #tmpUpdateRegimen  WHERE cccNumber = @cccNumber

		set rowcount 0

		WHILE @cccNumber IS NOT NULL
		BEGIN
			-- Get Patient Id 
			SELECT 
				@PatientId = id, @ptn_pk = ptn_pk , @ageAtLastVisit = DATEDIFF(YEAR,p.DateOfBirth, '2017-03-31')
			FROM gcPatientView p
			WHERE EnrollmentNumber = @fullcccNumber
			set @rc = @@ROWCOUNT
			if @rc = 0
			BEGIN
				SELECT 
					@PatientId = id, @ptn_pk = ptn_pk , @ageAtLastVisit = DATEDIFF(YEAR,p.DateOfBirth, '2017-03-31')
				FROM gcPatientView p
				WHERE EnrollmentNumber LIKE CONCAT('%',@cccNumber,'%') AND p.Sex = @sex
			END

			if @rc = 1 OR @@ROWCOUNT = 1
			BEGIN		
				-- Get Visit Date
				SELECT @RegimenStartdate = RegimenStartdate FROM #tmpUpdateRegimen WHERE cccNumber = @cccNumber

				if @RegimenStartdate IS NOT NULL 
				BEGIN
					-- Get Visit. If not existing, create a new one
					SELECT 
							@PatientMasterVisitID = Id, @UserID = CreatedBy
					FROM PatientMasterVisit 
					WHERE 
						PatientId = @PatientId AND ((DATEDIFF (hour, ISNULL([Start],VisitDate), @RegimenStartdate)) <= 24)

					if	@@ROWCOUNT = 0 
					BEGIN
						INSERT [dbo].[PatientMasterVisit]([PatientId], [ServiceId], [Start], [End], [VisitScheduled], [VisitBy], [VisitType], [VisitDate], [Active], [Status], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@PatientId, 1, @RegimenStartdate, @RegimenStartdate, NULL, NULL, NULL, @RegimenStartdate, 0, 1, NULL, GETDATE(), 1, 0)
			
						SET @PatientMasterVisitID = SCOPE_IDENTITY()
						SET @UserID = 1

					END

					SELECT 
						@LocationID=N'754', --jootrh
						@OrderedBy = @UserID,
						@UserID= @UserID,
						@DispensedBy = @UserID,
						@lastProvider = @UserID,
						@TreatmentProgram = N'222', --art
						@PrescribedDate = @RegimenStartdate,
						@DispensedDate = @RegimenStartdate,
						@ageAtLastVisit = @ageAtLastVisit,
						@daysToTCADate = 28, -- default value of 28
						@Regimen = 139,
						@RegimenType = Regimen,
						@RegimenLine = 215, -- Adult First Line
						@TreatmentPlan = 523,
						@encounterType = 1504 -- Pharmacy Encounter 
					FROM #tmpUpdateRegimen WHERE cccNumber = @cccNumber

					exec sp_SaveUpdatePharmacy_GreenCard 
						@PatientMasterVisitID=@PatientMasterVisitID,
						@PatientId=@PatientId,
						@LocationID=@LocationID,
						@OrderedBy=@OrderedBy,
						@UserID=@UserID,
						@RegimenType=@RegimenType,
						@DispensedBy=@DispensedBy,
						@RegimenLine=@RegimenLine,
						@ModuleID=N'',
						@TreatmentProgram=@TreatmentProgram,
						@PeriodTaken=N'0',
						@TreatmentPlan=@TreatmentPlan,
						@TreatmentPlanReason=N'0',
						@Regimen=@Regimen,
						@PrescribedDate=@PrescribedDate,
						@DispensedDate=@DispensedDate

					SET @ptn_pharmacy_pk = IDENT_CURRENT('ord_PatientPharmacyOrder')  

					exec sp_DeletePharmacyPrescription_GreenCard 
						@ptn_pharmacy_pk=@ptn_pharmacy_pk

					/*
					IF @ageAtLastVisit >= 18
						SET @drugId = 1022 -- Sulfa/TMX-Cotrimoxazole 960mg 800mg/160mg for Adults 
					ELSE
						SET @drugId = 1015 -- Sulfa/TMX-Cotrimoxazole 480mg 80mg for Paeds
					END
					*/

					SET @drugId = 1678 -- TDF/3TC/DTG
	
					IF @daysToTCADate < 28
						SET @qty = 84
					ELSE
						SET @qty = ROUND(@daysToTCADate/28,0)*28 --Round off the qty o the nearest 28 days(prescription period)
	
					exec sp_SaveUpdatePharmacyPrescription_GreenCard 
						@ptn_pharmacy_pk=@ptn_pharmacy_pk,
						@DrugId=@drugId,
						@BatchId=N'0',
						@FreqId=N'1',
						@Dose=N'1',
						@Duration=@qty,
						@qtyPres=@qty,
						@qtyDisp=@qty,
						@prophylaxis=N'0',
						@pmscm=N'0',
						@UserID=@lastProvider

						-- SELECT CONCAT('This is the regimen: ',@RegimenType)

						SET @encounterType = 1504
						-- Finally, Create Patient Encounter if the encounter doesn't exist
						if NOT EXISTS (SELECT * FROM PatientEncounter WHERE PatientMasterVisitId = @PatientMasterVisitID and EncounterTypeId = @encounterType)
						INSERT [dbo].[PatientEncounter]([PatientId], [EncounterTypeId], [Status], [PatientMasterVisitId], [EncounterStartTime], [EncounterEndTime], [ServiceAreaId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
						VALUES (@PatientId, @encounterType, 1, @PatientMasterVisitID, @RegimenStartdate, @RegimenStartdate, 204, NULL, getDate(), @lastProvider, 0)

					UPDATE DTGData SET Updated = 1, DateUpdated = getdate() WHERE newCCCNUmber = @cccNumber
				END			
			END
	
			DELETE FROM #tmpUpdateRegimen WHERE CccNumber = @cccNumber 
			SELECT @cccNumber = min(CCCNumber) FROM #tmpUpdateRegimen
			SELECT @sex = (CASE WHEN sex = 'MALE' THEN 51 ELSE 52 END), @fullCCCNumber = FullCCCNumber FROM #tmpUpdateRegimen  WHERE cccNumber = @cccNumber
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
