
-- select * from LookupItemView WHERE MasterName = 'ServiceArea'

 -- Add service Areas
 -- 

 -- Service Areas
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'ServiceArea')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('ServiceArea','Service Area')

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'MCH')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('MCH','MCH Clinic',0)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE name = 'TB')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('TB','TB Clinic',0)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE name = 'MAT')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('MAT','MAT Centre',0)

DECLARE @ServiceArea INT 
SELECT @ServiceArea = id from LookupMaster WHERE Name = 'ServiceArea'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE name = 'MCH'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@ServiceArea,(SELECT top 1 Id FROM LookupItem WHERE Name = 'MCH'),'MCH Clinic', (SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea))

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE name = 'TB'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@ServiceArea,(SELECT top 1 Id FROM LookupItem WHERE Name = 'TB'),'TB Clinic', (SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea))

IF EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'MoH 257 GREENCARD'))
	UPDATE LookupMasterItem SET DisplayName = 'PSC Clinic' WHERE LookupMasterId = @ServiceArea AND DisplayName = 'MoH 257 GREENCARD'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE name = 'MAT'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@ServiceArea,(SELECT top 1 Id FROM LookupItem WHERE Name = 'MAT'),'MAT Centre', (SELECT MAX(OrdRank)+1 FROM LookupMasterItem WHERE LookupMasterId = @ServiceArea))

--select * from PatientAppointment