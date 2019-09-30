DECLARE @tableName as NVARCHAR(250)
DECLARE @TableFk as NVARCHAR(50)
DECLARE @sqlStr as NVARCHAR(MAX)

DECLARE @preferredPatientId as Int = 45930	 -- 22805/12
DECLARE @unpreferredPatientId as Int = 7850 -- 22805-12
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
	DROP table #tmpVisitTables
END TRY
BEGIN CATCH
END CATCH

CREATE TABLE #tmpVisitTables (TableName NVARCHAR(250),TableFk NVARCHAR(50))

SET NOCOUNT ON;

SELECT 
	[Name] as TableName 
INTO #tmpTables
FROM sys.all_objects WHERE type= 'U' AND SCHEMA_ID = 1 AND [Name] NOT IN ('PatientmasterVisit')


SELECT @tableName = min(TableName) FROM #tmpTables

WHILE @tableName IS NOT NULL
BEGIN
		INSERT INTO #tmpVisitTables (TableName,TableFk) (
			SELECT  @tableName, [name] FROM sys.columns WHERE object_id = OBJECT_ID(@tableName) AND [name] in ('PatientMasterVisitId')  AND user_type_id = 56
		) 
	
	DELETE FROM #tmpTables WHERE TableName = @TableName
	SELECT @tableName = min(TableName) FROM #tmpTables
END
-- select * from #tmpVisitTables 
DROP TABLE #tmpTables
--select * from #tmpVisitTables
--return

SELECT @tableName = min(TableName) FROM #tmpVisitTables
WHILE @tableName IS NOT NULL
BEGIN
	SET @TableFk = (SELECT top 1 TableFk FROM #tmpVisitTables WHERE TableName = @tableName)

	SET @sqlStr = CONCAT('UPDATE [', @tableName, '] SET [PatientId] =', @preferredPatientId,' WHERE [PatientId] = ', @unpreferredPatientId, ' AND PatientMasterVisitId IN (255388,250945,245348)')


	print @sqlStr
	EXECUTE sp_executesql @sqlStr

	DELETE FROM #tmpVisitTables WHERE TableName = @TableName AND TableFk = @TableFk
	SELECT @tableName = min(TableName) FROM #tmpVisitTables
END