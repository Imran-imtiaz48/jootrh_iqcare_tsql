DELETE FROM PatientEncounter WHERE EncounterTypeId = 0

UPDATE PatientEncounter SET CreatedBy = ISNULL((SELECT top 1 CreatedBy FROM PatientMasterVisit v WHERE v.id = PatientEncounter.PatientMasterVisitId),1) WHERE CreatedBy = 0 

-- Recreated Encounters for PHARMACY
IF OBJECT_ID('tempdb..#tmpUpdateEnc') IS NOT NULL
	DROP TABLE #tmpUpdateEnc
GO

DECLARE @EncounterTypeId AS INT 
DECLARE @PatientMasterVisitId AS INT 
DECLARE @PatientId AS INT 
DECLARE @UserId AS INT 
DECLARE @VisitDate AS DATE 
DECLARE @VisitId AS INT 
DECLARE @PharmacyPk AS INT 
DECLARE @UpdatedRecords AS INT = 0

SELECT 
	DISTINCT ptn_pharmacy_pk as PharmacyPk, PatientId, PatientMasterVisitId, 1504 as EncounterTypeId, o.OrderedBy AS UserId, OrderedByDate as CreateDate
INTO #tmpUpdateEnc
FROM ord_PatientPharmacyOrder o
WHERE PatientMasterVisitId NOT IN (
	SELECT PatientMasterVisitId FROM PatientEncounter WHERE  PatientMasterVisitId > 0 AND EncounterTypeId > 0
)
AND  PatientMasterVisitId > 0 -- AND PatientId = 1302

select * from #tmpUpdateEnc

SELECT @PatientMasterVisitId = min(PatientMasterVisitId) FROM #tmpUpdateEnc 

WHILE @PatientMasterVisitId IS NOT NULL
BEGIN
	DECLARE @EncounterId AS INT 
	
	SELECT top 1 @PharmacyPk = PharmacyPk, @UserId = UserId, @EncounterTypeId = EncounterTypeId, @PatientMasterVisitId = PatientMasterVisitId, @PatientId = PatientId, @VisitDate = CreateDate FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId

	SELECT Id FROM PatientMasterVisit WHERE Id = @PatientMasterVisitId
	IF @@ROWCOUNT = 0
	BEGIN
		DELETE FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId AND PatientId = @PatientId AND EncounterTypeId = @EncounterTypeId
		exec sp_getVisit @VisitDate, @PatientId, @PatientMasterVisitId out, @VisitId out,  @UserId out
		UPDATE ord_PatientPharmacyOrder SET PatientMasterVisitId = @PatientMasterVisitId WHERE ptn_pharmacy_pk = @PharmacyPk
	END
	exec sp_GetEncounter 
		@PatientMasterVisitId,
		@EncounterTypeId,
		@PatientId,
		@UserId,
		@EncounterId OUT
	
	DELETE FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId AND PatientId = @PatientId AND EncounterTypeId = @EncounterTypeId
	SELECT @PatientMasterVisitId = min(PatientMasterVisitId) FROM #tmpUpdateEnc
	SET @UpdatedRecords = @UpdatedRecords +1
END
PRINT CONCAT('Pharmacy Records Updated: ',  @UpdatedRecords)
GO

-- Recreated Encounters for LAB
IF OBJECT_ID('tempdb..#tmpUpdateEnc') IS NOT NULL
	DROP TABLE #tmpUpdateEnc
GO

DECLARE @EncounterTypeId AS INT 
DECLARE @PatientMasterVisitId AS INT 
DECLARE @PatientId AS INT 
DECLARE @UserId AS INT 
DECLARE @VisitDate AS DATE 
DECLARE @VisitId AS INT 
DECLARE @OrderId AS INT 
DECLARE @UpdatedRecords AS INT = 0

SELECT 
	DISTINCT PatientId, PatientMasterVisitId, 1503 as EncounterTypeId, CreatedBy AS UserId, OrderDate, Id AS OrderId
INTO #tmpUpdateEnc
FROM ord_LabOrder
WHERE PatientMasterVisitId NOT IN (
	SELECT PatientMasterVisitId FROM PatientEncounter WHERE  PatientMasterVisitId > 0 AND EncounterTypeId > 0
)
AND  PatientMasterVisitId > 0

SELECT @PatientMasterVisitId = min(PatientMasterVisitId) FROM #tmpUpdateEnc 

WHILE @PatientMasterVisitId IS NOT NULL
BEGIN
	DECLARE @EncounterId AS INT 

	SELECT top 1 @OrderId = OrderId, @UserId = UserId, @EncounterTypeId = EncounterTypeId, @PatientMasterVisitId = PatientMasterVisitId, @PatientId = PatientId, @VisitDate = OrderDate FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId

	SELECT Id FROM PatientMasterVisit WHERE Id = @PatientMasterVisitId
	IF @@ROWCOUNT = 0
	BEGIN
		DELETE FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId AND PatientId = @PatientId AND EncounterTypeId = @EncounterTypeId
		exec sp_getVisit @VisitDate, @PatientId, @PatientMasterVisitId out, @VisitId out,  @UserId out
		UPDATE ord_LabOrder SET PatientMasterVisitId = @PatientMasterVisitId WHERE Id = @OrderId
	END

	exec sp_GetEncounter 
		@PatientMasterVisitId,
		@EncounterTypeId,
		@PatientId,
		@UserId,
		@EncounterId OUT
	
	DELETE FROM #tmpUpdateEnc WHERE PatientMasterVisitId = @PatientMasterVisitId AND PatientId = @PatientId AND EncounterTypeId = @EncounterTypeId
	SELECT @PatientMasterVisitId = min(PatientMasterVisitId) FROM #tmpUpdateEnc
	SET @UpdatedRecords = @UpdatedRecords + 1
END

PRINT CONCAT('Lab Records Updated: ',  @UpdatedRecords)
GO
