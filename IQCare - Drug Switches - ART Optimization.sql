IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'ARTOptimization')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('ARTOptimization', 'ART Optimization', 0)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = (select id from LookupMaster WHERE Name = 'DrugSwitches') AND LookupItemId = (select id from LookupItem WHERE Name = 'ARTOptimization'))
	INSERT INTO LookupMasterItem(LookupMasterId,LookupItemId, DisplayName, OrdRank) VALUES(
	(select id from LookupMaster WHERE Name = 'DrugSwitches'),
	(select id from LookupItem WHERE Name = 'ARTOptimization'),
	(select DisplayName from LookupItem WHERE Name = 'ARTOptimization'),
	(SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId=(select id from LookupMaster WHERE Name = 'DrugSwitches'))
	) 

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = (select id from LookupMaster WHERE Name = 'DrugSubstitutions') AND LookupItemId = (select id from LookupItem WHERE Name = 'ARTOptimization'))
	INSERT INTO LookupMasterItem(LookupMasterId,LookupItemId, DisplayName, OrdRank) VALUES(
	(select id from LookupMaster WHERE Name = 'DrugSubstitutions'),
	(select id from LookupItem WHERE Name = 'ARTOptimization'),
	(select DisplayName from LookupItem WHERE Name = 'ARTOptimization'),
	(SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId=(select id from LookupMaster WHERE Name = 'DrugSubstitutions'))
	) 
-- select * from LookupItemView WHERE MasterName = 'DrugSwitches' order by OrdRank
