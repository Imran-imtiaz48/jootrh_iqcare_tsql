IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'BaselineCD4')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('BaselineCD4','Baseline CD4',0)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'RoutineCD4')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('RoutineCD4','Routine CD4',0)

DECLARE @LabOrderReason INT 
SELECT @LabOrderReason = id from LookupMaster WHERE Name = 'LabOrderReason'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @LabOrderReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'BaselineCD4'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@LabOrderReason,(SELECT top 1 Id FROM LookupItem WHERE Name = 'BaselineCD4'),'Baseline CD4', (SELECT MAX(Ordrank)+1 FROM LookupMasterItem WHERE LookupMasterId = @LabOrderReason))

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @LabOrderReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'RoutineCD4'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@LabOrderReason,(SELECT top 1 Id FROM LookupItem WHERE Name = 'RoutineCD4'),'Routine CD4', (SELECT MAX(Ordrank)+1 FROM LookupMasterItem WHERE LookupMasterId = @LabOrderReason))

