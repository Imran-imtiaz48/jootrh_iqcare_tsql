UPDATE Mst_ItemMaster SET DeleteFlag = 0 WHERE abbreviation LIKE '%D4T%' AND DeleteFlag = 1

UPDATE lookupitem SET [Name] = 'AF3A' WHERE [Name] = '1A'
UPDATE lookupitem SET [Name] = 'CF3A' WHERE [Name] = '1B'

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AF3A') -- 1A
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AF3A','D4T + 3TC + NVP', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='CF3A') --1B
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('CF3A','D4T + 3TC + EFV', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AS2D')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AS2D','TDF + ABC + LPV/r', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AS4B')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AS4B','d4T + 3TC + ABC', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AS1C')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AS1C','AZT + 3TC + ABC', 0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AS2C')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AS2C','TDF + 3TC + AZT', 0)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultFirstLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AF3A'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultFirstLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AF3A'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AF3A'), 14)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultFirstLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'CF3A'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultFirstLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'CF3A'),(SELECT DisplayName FROM LookupItem WHERE Name = 'CF3A'), 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AS2D'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AS2D'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AS2D'), 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AS4B'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AS4B'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AS4B'), 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AS1C'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AS1C'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AS1C'), 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AS2C'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'AdultSecondLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AS2C'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AS2C'), 15)

UPDATE lookupitem SET [Name] = 'AF3B' WHERE [Name] = '4A'
UPDATE lookupitem SET [Name] = 'CF3B' WHERE [Name] = '4B'

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='AF3B')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('AF3B','D4T + 3TC + NVP', 0) --4A
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name ='CF3B')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES('CF3B','D4T + 3TC + EFV', 0) --4B

UPDATE lookupitem SET DisplayName = 'D4T + 3TC + EFV' WHERE DisplayName = 'D4T-3TC-EFV'
UPDATE lookupitem SET DisplayName = 'D4T + 3TC + NVP' WHERE DisplayName = 'D4T-3TC-NVP'


IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'PaedsFirstLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'AF3B'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'PaedsFirstLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'AF3B'),(SELECT DisplayName FROM LookupItem WHERE Name = 'AF3B'), 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId =(SELECT id FROM LookupMaster WHERE Name = 'PaedsFirstLineRegimen') AND LookupItemId = (SELECT id FROM LookupItem WHERE Name = 'CF3B'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId, DisplayName, OrdRank) 
	VALUES ((SELECT id FROM LookupMaster WHERE Name = 'PaedsFirstLineRegimen'), (SELECT id FROM LookupItem WHERE Name = 'CF3B'),(SELECT DisplayName FROM LookupItem WHERE Name = 'CF3B'), 16)



-- CF2D = ABC + 3TC + LPV/r

-- AS2D = TDF + ABC + LPV/r

/*
select * from Mst_ItemMaster WHERE abbreviation LIKE '%D4T%'

select * from LookupItemView WHERE MasterName = 'PaedsFirstLineRegimen' AND ItemName LIKE 'CF2A%'

select * from LookupItemView WHERE DisplayName LIKE '%D4T%'

SELECT * FROM LookupItem WHERE DisplayName LIKE '%ABC%'
SELECT * FROM LookupItem WHERE Name LIKE '1A'
SELECT * FROM LookupMaster WHERE Name = 'AdultFirstLineRegimen'
SELECT * FROM LookupMaster WHERE Name = 'PaedsFirstLineRegimen'
SELECT * FROM LookupMasterItem WHERE LookupMasterId =39
SELECT * FROM LookupMasterItem WHERE LookupMasterId =42
*/


/*
update LookupItem SET DisplayName = REPLACE(DisplayName,'d4T','D4T')
update LookupMasterItem SET DisplayName = REPLACE(DisplayName,'d4T','D4T')
select * from LookupItem WHERE Name = '4A'
*/


