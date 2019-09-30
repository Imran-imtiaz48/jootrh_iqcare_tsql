USE IQCARE_CPAD
GO

IF OBJECT_ID('tempdb..#tmpUpdatePIA') IS NOT NULL
	DROP TABLE #tmpUpdatePIA
GO

exec pr_OpenDecryptedSession
GO

SELECT        ID,PatientId AS FullCCCNumber, 
				CASE 
					WHEN LEN(PatientId) = 11 AND PatientId LIKE '13939%' THEN (SUBSTRING(PatientId, CHARINDEX('-', PatientId) + 1, LEN(PatientId))) 
					ELSE (SUBSTRING(PatientId, 1, (LEN(PatientId) - CHARINDEX('-', REVERSE(PatientId))))) 
				END 
				AS cccNumber, 
				sex, PatientName, VisitDate, PartnerHIVStatus, [Male Condom] AS MaleCondom, [Female Condom] AS FemaleCondom, [contraceptive?] AS Contraceptive, OC, IC, IUD, 
                IMP, TL, VASC, Abstinence, [Lac Anohrhea] AS LacAnorrhoea, [Natural], ECP, PlanningToConceive3M, RegularMenses, [last normal lmp] AS LastLMP, [pregnancy test results] AS PregnancyTestResults, ClientEligibleForFP, 
                ServiceForEligibleClient
INTO #tmpUpdatePIA
FROM            IQCarePIALinelist AS d
WHERE        (Updated = 0) AND ([MCH Number] IS NOT NULL) AND VisitDate IS NOT NULL AND (PatientId IS NOT NULL)

-- Select * from #tmpUpdatePIA WHERE ClientEligibleForFP IS NULL

DECLARE @Id as INT
DECLARE @VisitDate  AS DATE
DECLARE @CreateDate  AS DATETIME
DECLARE @PartnerHIVStatus AS NVARCHAR(50)
DECLARE @MaleCondom AS NVARCHAR(10)
DECLARE @FemaleCondom AS NVARCHAR(10)
DECLARE @Contraceptive AS NVARCHAR(10)
DECLARE @OC AS NVARCHAR(10)
DECLARE @IC AS NVARCHAR(10)
DECLARE @IUD AS NVARCHAR(10)
DECLARE @IMP AS NVARCHAR(10)
DECLARE @TL AS NVARCHAR(10)
DECLARE @VASC AS NVARCHAR(10)
DECLARE @Abstinence AS NVARCHAR(10)
DECLARE @LacAnorrhoea AS NVARCHAR(10)
DECLARE @Natural AS NVARCHAR(10)
DECLARE @ECP AS NVARCHAR(10)
DECLARE @PlanningToConceive3M AS NVARCHAR(10)
DECLARE @RegularMenses AS NVARCHAR(10)
DECLARE @LastLMP AS NVARCHAR(10)
DECLARE @PregnancyTestResults AS NVARCHAR(10)
DECLARE @ClientEligibleForFP AS NVARCHAR(10)
DECLARE @ServiceForEligibleClient AS NVARCHAR(10)
DECLARE @FullcccNumber as NVARCHAR(50)
DECLARE @cccNumber as NVARCHAR(50)
DECLARE @sex as NVARCHAR(5)
DECLARE @firstName as NVARCHAR(50)
DECLARE @PregnancyStatusId AS INT
DECLARE @FamilyPlanningStatusId AS INT
DECLARE @PartnerHIVStatusId AS INT
DECLARE @PatientFpId AS INT

DECLARE @rc AS INT
DECLARE @ptnPk AS INT
DECLARE @PatientId AS INT

DECLARE @PatientMasterVisitId AS INT
DECLARE @VisitId AS INT 
DECLARE @UserId AS INT 
DECLARE @Success AS TINYINT


SELECT @PatientId = min(Id) FROM #tmpUpdatePIA

set rowcount 0

WHILE @PatientId IS NOT NULL
BEGIN
			SELECT
				@PatientId = Id, 
				@sex = (CASE WHEN sex = 'M' THEN 51 ELSE 52 END), @cccNumber = CCCNUmber, @fullCCCNumber = FullCCCNumber, @firstName = (SUBSTRING([PatientName],0,CHARINDEX(' ', [PatientName]))),  
				@VisitDate = VisitDate , 
				@PartnerHIVStatus = PartnerHIVStatus , 
				@MaleCondom = MaleCondom , 
				@FemaleCondom = FemaleCondom , 
				@Contraceptive = Contraceptive , 
				@OC = OC , 
				@IC = IC , 
				@IUD = IUD , 
				@IMP = IMP , 
				@TL = TL , 
				@VASC = VASC , 
				@Abstinence = Abstinence , 
				@LacAnorrhoea = LacAnorrhoea , 
				@Natural = Natural , 
				@ECP = ECP , 
				@PlanningToConceive3M = PlanningToConceive3M , 
				@RegularMenses = RegularMenses , 
				@LastLMP = LastLMP , 
				@PregnancyTestResults = PregnancyTestResults , 
				@ClientEligibleForFP = ClientEligibleForFP , 
				@ServiceForEligibleClient = ServiceForEligibleClient , 
				@FullcccNumber = FullcccNumber , 
				@cccNumber = cccNumber , 
				@sex = sex , 
				@Createdate = GETDATE(),
				@UserId = 1
			FROM #tmpUpdatePIA  WHERE Id = @PatientId

			-- Get Patient Id 
			/*
			SELECT 
				@PatientId = id, @ptnpk = ptn_pk
			FROM gcPatientView p
			WHERE EnrollmentNumber = @fullcccNumber

			set @rc = @@ROWCOUNT
			if @rc = 0
			BEGIN
				SELECT 
					@PatientId = id, @ptnpk = ptn_pk
				FROM gcPatientView p
				WHERE EnrollmentNumber LIKE CONCAT('%',@cccNumber,'%') AND p.Sex = @sex AND CONCAT(Firstname,' ',MiddleName,'',LastName) LIKE CONCAT('%',@firstName,'%')
			END
			*/

			IF @rc = 1 OR @@ROWCOUNT = 1 -- Begin updating IPT Data
			BEGIN
				-- upload excel
				-- run sps
					-- get_visit
					-- updateIPT

				exec sp_getVisit @VisitDate, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT
				
				IF @PregnancyTestResults = 'Positive'
					SET @PregnancyStatusId = 81

				IF @PregnancyTestResults = 'Negative' OR  @PregnancyTestResults = 'N/A'
					SET @PregnancyStatusId = 82

				-- Check for existence first
				IF NOT EXISTS (SELECT * FROM pregnancyIndicator WHERE PatientID = @PatientId AND VisitDate = @VisitDate) AND @PregnancyStatusId IS NOT NULL
					exec sp_executesql N'INSERT [dbo].[pregnancyIndicator]([PatientId], [PatientMasterVisitId], [VisitDate], [LMP], [EDD], [PregnancyStatusId], [AncProfile], [AncProfileDate], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
					VALUES (@0, @1, @2, NULL, NULL, @3, @4, NULL, NULL, @5, @6, @7)',
					N'@0 int,@1 int,@2 datetime2(7),@3 int,@4 int,@5 datetime2(7),@6 int,@7 bit',
					@0=@PatientId,@1=@PatientMasterVisitId,@2=@VisitDate,@3=@PregnancyStatusId,@4=1,@5=@CreateDate,@6=@UserId,@7=0
				
				IF @Contraceptive = 'Y'
					SET @FamilyPlanningStatusId = 1
					ELSE IF @Contraceptive = 'N'
						SET @FamilyPlanningStatusId = 2
						ELSE
							SET @FamilyPlanningStatusId = 0							

				SELECT @PatientFpId = Id FROM PatientFamilyPlanning WHERE PatientID = @PatientId AND VisitDate = @VisitDate

				IF @@ROWCOUNT = 0
					exec sp_executesql N'INSERT [dbo].[PatientFamilyPlanning]([PatientId], [PatientMasterVisitId], [VisitDate], [FamilyPlanningStatusId], [ReasonNotOnFPId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
					VALUES (@0, @1, @2, @3, @4, NULL, @5, @6, @7)',
					N'@0 int,@1 int,@2 datetime2(7),@3 int,@4 int,@5 datetime2(7),@6 int,@7 bit',
					@0=@PatientId,@1=@PatientMasterVisitId,@2=@VisitDate,@3=@FamilyPlanningStatusId,@4=0,@5=@CreateDate,@6=@UserId,@7=0
				
				IF @PatientFpId IS NULL
					SET @PatientFpId =  IDENT_CURRENT('PatientFamilyPlanning')

				IF @MaleCondom = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 4
					  
				IF @FemaleCondom = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 4
				 
				IF @OC = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 6
				 
				IF @IC = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 7
				 
				IF @IUD = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 9
				 
				IF @IMP = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 8

				IF @TL = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 13
				 
				IF @VASC = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 14
				 
				IF @Abstinence = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 15
				 
				IF @LacAnorrhoea = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 10
				 
				IF @Natural = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 10
				 
				IF @ECP = 'Y'
					exec sp_saveFpMethod @PatientId, @PatientFpId, 5
				 
				IF @PartnerHIVStatus = 'Positive'
					SET @PartnerHIVStatusId = 1443
				
				IF @PartnerHIVStatus = 'Negative'
					SET @PartnerHIVStatusId = 1444

				IF @PartnerHIVStatus = 'N/A' OR @PartnerHIVStatus = 'Not Applicable'
					SET @PartnerHIVStatusId = 104

				IF @PartnerHIVStatus = 'Uknown' OR @PartnerHIVStatus = 'Unknown'
					SET @PartnerHIVStatusId = 500

				IF @PartnerHIVStatus = 'Known Positive'
					SET @PartnerHIVStatusId = 1488
				
				IF NOT EXISTS (SELECT * FROM PatientPregnancyIntentionAssessment WHERE PatientId = @PatientId AND VisitDate = @VisitDate)
					exec sp_executesql N'INSERT [dbo].[PatientPregnancyIntentionAssessment]
					([PatientId], [PatientMasterVisitId], [VisitDate], [PartnerHivStatus], [ClientEligibleForFP], [ServiceForEligibleClient], [ReasonForFpIneligibility], [PlanningToConceive3M], [RegularMenses], [InitiatedOnART], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
					VALUES (@0, @1, @2, @3, @4, @5, @6, @7, @8, NULL, NULL, @9, @10, @11)',
					N'@0 int,@1 int,@2 datetime2(7),@3 int,@4 nvarchar(max) ,@5 int,@6 int,@7 nvarchar(max) ,@8 nvarchar(max) ,@9 datetime2(7),@10 int,@11 bit',
					@0=@PatientId,@1=@PatientMasterVisitId,@2=@VisitDate,@3=@PartnerHIVStatusId,@4=NULL,@5=0,@6=0,@7=@PlanningToConceive3M,@8=NULL,@9=@CreateDate,@10=@UserId,@11=0										

				UPDATE IQCarePIALineList SET Updated = 1, DateUpdated = GETDATE() WHERE PatientId = @FullcccNumber
								
			END
			ELSE
			BEGIN
				UPDATE IQCarePIALineList SET Updated = 4, DateUpdated = getdate() WHERE PatientId = @fullcccNumber				
			END

			--print @FullCCCNUmber
			DELETE FROM #tmpUpdatePIA WHERE FullCccNumber = @FullcccNumber 
			SELECT @PatientId = min(Id) FROM #tmpUpdatePIA

END
go

exec pr_CloseDecryptedSession
go