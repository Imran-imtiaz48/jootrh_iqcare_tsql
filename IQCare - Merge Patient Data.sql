DECLARE @tableName as NVARCHAR(250)
DECLARE @patientFk as NVARCHAR(50)
DECLARE @sqlStr as NVARCHAR(MAX)

DECLARE @preferredPatientId as Int = 5780	 -- 22805/12
DECLARE @unpreferredPatientId as Int = 1647 -- 22805-12
DECLARE @preferredPtnPk as Int
DECLARE @unpreferredPtnPk as Int
DECLARE @preferredPersonId as Int
DECLARE @unPreferredPersonId as Int

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

CREATE TABLE #tmpPatientTables (TableName NVARCHAR(250),PatientFK NVARCHAR(50))

SET NOCOUNT ON;

SELECT 
	[Name] as TableName 
INTO #tmpTables
FROM sys.all_objects WHERE type= 'U' AND SCHEMA_ID = 1 AND [Name] NOT IN ('Patient', 'mst_Patient', 'person', 'PatientIdentifier', 'Lnk_PatientProgramStart', 'ARTPataient')


SELECT @tableName = min(TableName) FROM #tmpTables

WHILE @tableName IS NOT NULL
BEGIN
		INSERT INTO #tmpPatientTables (TableName,PatientFk) (
			SELECT  @tableName, [name] FROM sys.columns WHERE object_id = OBJECT_ID(@tableName) AND [name] in ('PatientId','Ptn_pk','PatientPk','PtnPk','Patient_Pk', 'PersonId')  AND user_type_id = 56
		) 
	
	DELETE FROM #tmpTables WHERE TableName = @TableName
	SELECT @tableName = min(TableName) FROM #tmpTables
END
-- select * from #tmpPatientTables 
DROP TABLE #tmpTables


SELECT @tableName = min(TableName) FROM #tmpPatientTables
WHILE @tableName IS NOT NULL
BEGIN
	SET @patientFk = (SELECT top 1 PatientFk FROM #tmpPatientTables WHERE TableName = @tableName)

	IF @patientFk = 'PatientId'
		BEGIN
			SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET [PatientId] =', @preferredPatientId,' WHERE [', @patientFk,'] = ', @unpreferredPatientId)
		END

	IF @patientFk =  'PersonId'
		BEGIN
			SET @preferredPersonId = (SELECT PersonId FROM Patient WHERE Id = @preferredPatientId)
			SET @unpreferredPersonId = (SELECT PersonId FROM Patient WHERE Id = @unpreferredPatientId)
			SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET [', @patientFk , '] = ', @preferredPersonId,' WHERE [', @patientFk,'] = ', @unpreferredPersonId)
		END

	IF @patientFk = 'Ptn_pk'
		BEGIN
			SET @preferredPtnPk = (SELECT Ptn_Pk FROM Patient WHERE Id = @preferredPatientId)
			SET @unpreferredPtnPk = (SELECT Ptn_Pk FROM Patient WHERE Id = @unpreferredPatientId)
			SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET [', @patientFk , '] = ', @preferredPtnPk,' WHERE [', @patientFk,'] = ', @unpreferredPtnPk)
		END

	print @sqlStr
	EXECUTE sp_executesql @sqlStr

	DELETE FROM #tmpPatientTables WHERE TableName = @TableName AND PatientFk = @PatientFk
	SELECT @tableName = min(TableName) FROM #tmpPatientTables
END

-- Soft delete the reevant patient master tables
UPDATE Patient SET DeleteFlag = 1 WHERE Id = @unpreferredPatientId
UPDATE Person SET DeleteFlag = 1 WHERE Id = (SELECT PersonId FROM Patient WHERE Id = @unpreferredPatientId)
UPDATE mst_Patient SET DeleteFlag = 1 WHERE Ptn_Pk = (SELECT Ptn_Pk FROM Patient WHERE Id = @unpreferredPatientId)
