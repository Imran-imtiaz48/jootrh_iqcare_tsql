
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#tmpIPTPatients') IS NOT NULL
	DROP TABLE #tmpIPTPatients
GO


SELECT 
	DISTINCT ISNULL(pid.PatientId, pid1.PatientId) as PatientId, ipt.[PAtientId] as CCCNumber, 
	ipt.TINumber, ipt.[Name], ipt.DateDispensed AS IptStart,  DATEADD(D, lastIptDispense.duration, lastIptDispense.DateDispensed) AS IptEnd, ipt.IPTEnd as GivenIptEnd, DATEADD(M,6,ipt.DateDispensed) AS CalculatedIptEnd,
	CASE WHEN DATEADD(D, lastIptDispense.duration, lastIptDispense.DateDispensed) >= ISNULL(ipt.IPTEnd, DATEADD(M,6,ipt.DateDispensed)) AND DATEDIFF(M,ipt.DateDispensed,lastIptDispense.DateDispensed) < 12 THEN 'Completed' ELSE NULL END AS CompletedIpt
INTO #tmpIptPatients
FROM (
	SELECT * FROM (
		SELECT id, Updated, LTRIM([Patient Id]) PatientId, [TI NUmber] as TINumber,[Name],[IPT End] as IPTEnd ,[date dispensed] as DateDispensed, [Pres# Duration] as Duration, ROW_NUMBER() OVER (PARTITION BY [Patient Id] ORDER BY [date dispensed] ASC) rown FROM adt_all_ipt --WHERE [Patient Id]= '13939-03667'
	) li WHERE li.rown = 1
) ipt 
INNER JOiN (
	SELECT * FROM (
		SELECT id, LTRIM([Patient Id]) PatientId, [date dispensed] as DateDispensed, [Pres# Duration] as Duration, ROW_NUMBER() OVER (PARTITION BY [Patient Id] ORDER BY [date dispensed] DESC) rown FROM adt_all_ipt --WHERE [Patient Id]= '13939-22720'
	) li WHERE li.rown = 1
) lastIptDispense ON lastIptDispense.PatientId = ipt.PatientId
LEFT JOIN (
	SELECT PID.PatientId, PID.IdentifierValue, dbo.PARSE_NAME_UDF(PatientName, 'F') AS FirstName, dbo.PARSE_NAME_UDF(PatientName, 'M') AS MiddleName, dbo.PARSE_NAME_UDF(PatientName, 'L') AS LastName FROM PatientIdentifier PID INNER JOIN Patient P ON PID.PatientId = P.Id INNER JOIN IQTools_KeHMIS.dbo.tmp_PatientMaster MP ON MP.PatientPK = P.ptn_pk
	) pid ON LTRIM(pid.IdentifierValue) = LTRIM(ipt.[PatientId]) AND 
	(
		SOUNDEX(pid.[FirstName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'F')) OR 
		(SOUNDEX(pid.[MiddleName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'M')) AND LEN(pid.MiddleName) > 0) OR 
		(SOUNDEX(pid.[LastName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid.LastName) > 0) OR
		(SOUNDEX(pid.[LastName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'M')) AND LEN(pid.LastName) > 0) OR
		(SOUNDEX(pid.[FirstName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid.LastName) > 0) OR
		(SOUNDEX(pid.[MiddleName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid.MiddleName) > 0) 
	) 
LEFT JOIN (
	SELECT PID.PatientId, PID.IdentifierValue, dbo.PARSE_NAME_UDF(PatientName, 'F') AS FirstName, dbo.PARSE_NAME_UDF(PatientName, 'M') AS MiddleName, dbo.PARSE_NAME_UDF(PatientName, 'L') AS LastName FROM PatientIdentifier PID INNER JOIN Patient P ON PID.PatientId = P.Id INNER JOIN IQTools_KeHMIS.dbo.tmp_PatientMaster MP ON MP.PatientPK = P.ptn_pk
	) pid1 ON LTRIM(pid1.IdentifierValue) = LTRIM(ipt.[TINUmber]) AND 
	(
		SOUNDEX(pid1.[FirstName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'F')) OR 
		(SOUNDEX(pid1.[MiddleName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'M')) AND LEN(pid1.MiddleName) > 0) OR 
		(SOUNDEX(pid1.[LastName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid1.LastName) > 0) OR
		(SOUNDEX(pid1.[LastName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'M')) AND LEN(pid1.LastName) > 0) OR
		(SOUNDEX(pid1.[FirstName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid.LastName) > 0) OR
		(SOUNDEX(pid1.[MiddleName]) LIKE SOUNDEX(dbo.PARSE_NAME_UDF([Name], 'L')) AND LEN(pid1.MiddleName) > 0) 
	)
WHERE 
ISNULL(pid.PatientId, pid1.PatientId) IS NOT NULL AND ipt.Updated = 0  
--AND 
--ipt.[PatientId]  IN ('13939-25055') --AND ISNULL(pid.PatientId, pid1.PatientId) = 4

--SELECT * FROM #tmpIPTPatients -- WHERE [Name] LIKE '%FREDrick%'
--return
-- SELECT * FROM adt_all_ipt
DECLARE @DateStartedIpt  AS DATE
DECLARE @Outcomestring AS NVARCHAR(50)
DECLARE @Outcome AS INT
DECLARE @OutcomeDate as DATE
DECLARE @ReasonsForDiscontinuation as NVARCHAR(100)
DECLARE @FullcccNumber as NVARCHAR(50)
DECLARE @cccNumber as NVARCHAR(50)
DECLARE @sex as INT
DECLARE @firstName as NVARCHAR(50)

DECLARE @rc AS INT
DECLARE @ptnPk AS INT
DECLARE @PatientId AS INT

DECLARE @PatientMasterVisitId AS INT
DECLARE @VisitId AS INT 
DECLARE @UserId AS INT 
DECLARE @Success AS TINYINT

SELECT @PatientId = min(PatientId) FROM #tmpIPTPatients


WHILE @PatientId IS NOT NULL
BEGIN
	SELECT 
		@firstName = (SUBSTRING([Name],0,CHARINDEX(' ', [Name]))),  @cccNumber = CCCNumber,
		@DateStartedIpt = IptStart,@Outcomestring = CompletedIpt, @OutcomeDate = IptEnd
	FROM #tmpIPTPatients  WHERE PatientId = @PatientId

-- xxxxxxxxxxxxx
	exec sp_getVisit @DateStartedIpt, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT

	IF @Outcomestring LIKE '%completed%'
		SET @Outcome = 525
	ELSE
		SET @Outcome = 0

	exec sp_updateIPT @PatientId, @PatientMasterVisitId, @DateStartedIpt, @Outcome, @OutcomeDate, @userId, @ReasonsForDiscontinuation, @Success OUT 
	
	IF @success = 1 
	BEGIN

		IF OBJECT_ID('tempdb..#tmpIptPrescription') IS NOT NULL
			DROP TABLE #tmpIptPrescription

		SELECT id, [Date Dispensed] AS DateDispensed, [Pres# Duration] AS Duration 
		INTO #tmpIptPrescription
		FROM adt_all_ipt 
		WHERE [Patient Id] = @cccNumber


		DECLARE @DateDispensed AS DATE 
		DECLARE @Duration AS INT, @id AS INT 
		DECLARE	@LocationID AS INT =N'754' --jootrh
		DECLARE @TreatmentProgram AS INT = N'225'
		DECLARE @drugId AS INT = 235 -- Isoniazid-INH 300mg -- select * from Mst_Drug WHERE DrugName LIKE '%Isoniazid-INH 300mg%'
		DECLARE @ptn_pharmacy_pk AS INT
		
		SELECT @id = min(id) FROM #tmpIptPrescription

		WHILE @id IS NOT NULL
		BEGIN

			SELECT @Duration = Duration, @id = id, @DateDispensed = DateDispensed FROM #tmpIptPrescription WHERE id = @id
		
			exec sp_getVisit @DateDispensed, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT

			-- Start Autodispense IPT
			IF NOT EXISTS (SELECT * FROM ord_PatientPharmacyOrder o WHERE o.PatientId = @PatientId AND PatientMasterVisitId = @PatientMasterVisitId)
			BEGIN
				exec sp_SaveUpdatePharmacy_GreenCard1 
					@PatientMasterVisitID=@PatientMasterVisitID,
					@PatientId=@PatientId,
					@LocationID=@LocationID,
					@OrderedBy=@UserId,
					@UserID=@UserID,
					@RegimenType=N'',
					@DispensedBy=@UserId,
					@RegimenLine=N'0',
					@ModuleID=N'',
					@TreatmentProgram=@TreatmentProgram,
					@PeriodTaken=N'0',
					@TreatmentPlan=N'0',
					@TreatmentPlanReason=N'0',
					@Regimen=N'0',
					@PrescribedDate=@DateDispensed,
					@DispensedDate=@DateDispensed

				SET @ptn_pharmacy_pk = IDENT_CURRENT('ord_PatientPharmacyOrder')  
			END
			ELSE
				SELECT @ptn_pharmacy_pk = ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientId = @PatientId AND PatientMasterVisitId = @PatientMasterVisitId

			IF NOT EXISTS (SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder WHERE ptn_pharmacy_pk = @ptn_pharmacy_pk AND Drug_Pk = @drugId)
			BEGIN		
				exec sp_SaveUpdatePharmacyPrescription_GreenCard 
					@ptn_pharmacy_pk=@ptn_pharmacy_pk,
					@DrugId=@drugId,
					@BatchId=N'0',
					@FreqId=N'1',
					@Dose=N'1',
					@Duration=@Duration,
					@qtyPres=@Duration,
					@qtyDisp=@Duration,
					@prophylaxis=N'0',
					@pmscm=N'0',
					@UserID=@UserId
			END
			-- End Autodispense IPT
			print @id
			DELETE FROM #tmpIptPrescription WHERE id = @id
			UPDATE adt_all_ipt SET Updated = 1 WHERE id = @id
			SELECT @id = min(id) FROM #tmpIptPrescription

		END

	END		

-- xxxxxxxxxxxxx

	DELETE FROM #tmpIPTPatients WHERE PatientId = @PatientId
	SELECT @PatientId = min(PatientId) FROM #tmpIPTPatients
END



-- For each client, 
--  update IPT start and Pit Outcome
-- For each date that a dispense took place,
--  check if an ipt dispense was done, then autodispense if missing
		
