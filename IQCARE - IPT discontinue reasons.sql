-- IPT Discontinue reasons

IF NOT EXISTS (SELECT * FROM LookupMaster WHERE [Name] = 'IPTDiscontinuationReason')
	INSERT INTO LookupMaster (Name,DisplayName,DeleteFlag) VALUES ('IPTDiscontinuationReason','IPT Discontinue Reason',0)

DECLARE @IPTDiscontinuationReason INT 
SELECT @IPTDiscontinuationReason = id from LookupMaster WHERE Name = 'IPTDiscontinuationReason'

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'Toxicity')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Toxicity','Toxicity', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'DevelopedTB')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('DevelopedTB','Developed TB', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'Stopped')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Stopped','Stopped', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'Other')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Other','Other', 0)

IF @IPTDiscontinuationReason IS NOT NULL AND NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @IPTDiscontinuationReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Toxicity'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@IPTDiscontinuationReason,(SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Toxicity'),(SELECT top 1 DisplayName FROM LookupItem WHERE [Name] = 'Toxicity'),1)
IF @IPTDiscontinuationReason IS NOT NULL AND NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @IPTDiscontinuationReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE [Name] = 'DevelopedTB'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@IPTDiscontinuationReason,(SELECT top 1 Id FROM LookupItem WHERE [Name] = 'DevelopedTB'),(SELECT top 1 DisplayName FROM LookupItem WHERE [Name] = 'DevelopedTB'),2)
IF @IPTDiscontinuationReason IS NOT NULL AND NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @IPTDiscontinuationReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Stopped'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@IPTDiscontinuationReason,(SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Stopped'),(SELECT top 1 DisplayName FROM LookupItem WHERE [Name] = 'Stopped'),3)
IF @IPTDiscontinuationReason IS NOT NULL AND NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @IPTDiscontinuationReason AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Other'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@IPTDiscontinuationReason,(SELECT top 1 Id FROM LookupItem WHERE [Name] = 'Other'),(SELECT top 1 DisplayName FROM LookupItem WHERE [Name] = 'Other'),4)

