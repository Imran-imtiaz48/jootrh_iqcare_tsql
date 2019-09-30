 -- Service Areas
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'HTSEntryPoints')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('HTSEntryPoints','HTS Entry Points')

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'VMMC')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('VMMC','VMMC Clinic',0)

 IF NOT EXISTS (SELECT * FROM LookupItem WHERE name = 'GBVRC')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('GBVRC','GBVRC',0)


DECLARE @ServiceArea INT 
SELECT @ServiceArea = id from LookupMaster WHERE Name = 'HTSEntryPoints'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE name = 'VMMC'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@ServiceArea,(SELECT top 1 Id FROM LookupItem WHERE Name = 'VMMC'),'VMMC Clinic', (SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea))

 IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE name = 'GBVRC'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@ServiceArea,(SELECT top 1 Id FROM LookupItem WHERE Name = 'GBVRC'),'GBVRC', (SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea))

select * from hts