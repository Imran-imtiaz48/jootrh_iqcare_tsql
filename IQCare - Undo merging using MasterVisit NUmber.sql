DECLARE @tableName as NVARCHAR(250)
DECLARE @patientFk as NVARCHAR(50)
DECLARE @sqlStr as NVARCHAR(MAX)
DECLARE @PatientId as Int = 785
DECLARE @PtnPk as Int = 786
DECLARE @PatientMasterVisitId as Int = 785

BEGIN TRY 
	DROP table #tmpTables
END TRY
BEGIN CATCH
END CATCH

BEGIN TRY 
	DROP table #tmpPatientTables
END TRY
BEGIN CATCH
END CATCH

SET NOCOUNT ON;

SELECT 
	OBJECT_NAME(object_id) as TableName 
INTO #tmpPatientTables
FROM sys.columns WHERE [Name] LIKE 'PatientMasterVisitId' --AND [Name] NOT IN ('Patient', 'mst_Patient', 'person', 'PatientIdentifier', 'Lnk_PatientProgramStart', 'ARTPataient')

SELECT COUNT(*) FROM #tmpPatientTables

SELECT @tableName = min(TableName) FROM #tmpPatientTables
WHILE @tableName IS NOT NULL
BEGIN
	SET @patientFk = (SELECT [name] FROM Sys.Columns WHERE OBJECT_ID = OBJECT_ID(@tableName) AND ([name] = 'PatientId'))

	IF @patientFk = 'PatientId'
		BEGIN
			SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET [PatientId] =', @PatientId,' WHERE PatientMasterVisitId = ', @PatientMasterVisitId)
			print @sqlStr
			EXECUTE sp_executesql @sqlStr
		END

	SET @patientFk = (SELECT [name] FROM Sys.Columns WHERE OBJECT_ID = OBJECT_ID(@tableName) AND ([name] = 'Ptn_pk'))

	IF @patientFk = 'Ptn_pk'
		BEGIN
			SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET Ptn_pk = ', @PtnPk,' WHERE PatientMasterVisitId = ', @PatientMasterVisitId)
			print @sqlStr
			EXECUTE sp_executesql @sqlStr
		END


	DELETE FROM #tmpPatientTables WHERE TableName = @TableName
	SELECT @tableName = min(TableName) FROM #tmpPatientTables
END

DROP TABLE #tmpPatientTables
