--select * from LookupItemView WHERE MasterName like '%first%'

/*
SELECT * FROM LookupItemView WHERE ItemName like '%AF%' --AND DisplayName LIKE '%ETV%'


SELECT * FROM LookupItem l WHERE id = 153

SELECT * FROM LookupMaster WHERE id = 41

SELECT * FROM LookupMasterItem WHERE LookupMasterId = 39 and LookupItemId = 153

*/

DECLARE @AdultThirdlineRegimen INT 
SELECT @AdultThirdlineRegimen = id from LookupMaster WHERE Name = 'AdultThirdlineRegimen'

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT1A')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT1A', 'RAL + 3TC + DRV + RTV', 13)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT1B')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT1B', 'RAL + 3TC + DRV + RTV + AZT', 14)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT1C')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT1C', 'RAL + 3TC + DRV + RTV + TDF', 15)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2A')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2A', 'ETV + 3TC + DRV + RTV', 16)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X1')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X1', 'TDF + FTC + DRV + RTV + RAL', 17)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X2')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X2', 'ETV + RAL + DRV + RTV', 18)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X3')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X3', 'TDF + 3TC + DTG + DRV + RTV', 19)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X4')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X4', 'TDF + 3TC + DTG + DRV + RTV + ETV', 20)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X5')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X5', 'ABC + 3TC + DRV + RTV + RAL', 21)
	
IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X6')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X6', 'TDF + 3TC + DTG + DRV + RTV/r', 22)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X7')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X7', 'TDF + DTG + FTC + DRV + RTV/r', 23)

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AT2X8')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AT2X8', 'TDF + 3TC + ATV/r', 24)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2A'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2A'), 'ETV + 3TC + DRV + RTV', 13)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT1B'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT1B'), 'RAL + 3TC + DRV + RTV + AZT', 14)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT1C'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT1C'), 'RAL + 3TC + DRV + RTV + TDF', 15)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2A'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2A'), 'ETV + 3TC + DRV + RTV', 16)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X1'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X1'), 'TDF + FTC + DRV + RTV + RAL', 17)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X2'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X2'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X2'), 18)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X3'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X3'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X3'), 19)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X4'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X4'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X4'), 20)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X5'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X5'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X5'), 21)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X6'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X6'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X6'), 22)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X7'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X7'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X7'), 23)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultThirdlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X8'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultThirdlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AT2X8'), (SELECT top 1 DisplayName FROM LookupItem WHERE Name = 'AT2X8'), 24)


DECLARE @PaedsThirdLineRegimen INT 
SELECT @PaedsThirdLineRegimen = id from LookupMaster WHERE Name = 'PaedsThirdlineRegimen'
select @PaedsThirdLineRegimen

-- select * from LookupItem WHERE Name LiKE 'CT%'

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'CT3X1')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('CT3X1', 'TDF + 3TC + DTG + DRV + RTV + ETV', 0)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @PaedsThirdLineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'CT3X1'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@PaedsThirdLineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'CT3X1'), (SELECT top 1 Name FROM LookupItem WHERE Name = 'CT3X1'), (SELECT MAX(OrdRank) + 1 FROM LookupMasterItem WHERE LookupMasterId = @PaedsThirdLineRegimen))

DECLARE @AdultFirstlineRegimen INT 
SELECT @AdultFirstlineRegimen = id from LookupMaster WHERE Name = 'AdultFirstlineRegimen'
select @AdultFirstlineRegimen

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AF2X1')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AF2X1', 'DTG + 3TC', 14)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @AdultFirstlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AF2X1'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@AdultFirstlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AF2X1'), 'DTG + 3TC', 14)


DECLARE @PaedsFirstlineRegimen INT 
SELECT @PaedsFirstlineRegimen = id from LookupMaster WHERE Name = 'PaedsFirstlineRegimen'
select @PaedsFirstlineRegimen

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'AF2E')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('AF2E', 'TDF + 3TC + DTG', 0)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @PaedsFirstlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'AF2E'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@PaedsFirstlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'AF2E'), (SELECT top 1 Name FROM LookupItem WHERE Name = 'AF2E'), (SELECT MAX(OrdRank) + 1 FROM LookupMasterItem WHERE LookupMasterId = @PaedsFirstlineRegimen))


DECLARE @PaedsSecondlineRegimen INT 
SELECT @PaedsSecondlineRegimen = id from LookupMaster WHERE Name = 'PaedsSecondlineRegimen'
select @PaedsSecondlineRegimen

IF NOT EXISTS (SELECT * FROM LookupItem WHERE Name = 'CS2X1')
	INSERT INTO LookupItem (Name, DisplayName, DeleteFlag) VALUES ('CS2X1', 'TDF + 3TC + LPV/r + NVP', 0)

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @PaedsSecondlineRegimen AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE Name = 'CS2X1'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@PaedsSecondlineRegimen,(SELECT top 1 Id FROM LookupItem WHERE Name = 'CS2X1'), (SELECT top 1 Name FROM LookupItem WHERE Name = 'CS2X1'), (SELECT MAX(OrdRank) + 1 FROM LookupMasterItem WHERE LookupMasterId = @PaedsSecondlineRegimen))


--select * from LookupItem WHERE Name LiKE 'AF2E%'

--select top 10 * from LookupMasterItem ORDER BY LookupItemid desc

--delete from LookupMasterItem WHERE LookupMasterId = 42 AND LookupItemId = 2283

--delete from LookupItem WHERE id = 2283

select * from LookupItemView WHERE MasterName = 'CT3X'

select * from RegimenMapView WHERE patientId  = 10350 ORDER BY VIsitDate DESC

select * from PatientTreatmentTrackerViewD4T  WHERE PatientId = 38338
 ORDER BY RegimenStartDate DESC

select * from PatientTreatmentTrackerView WHERE PatientId = 2928 ORDER BY RegimenStartDate DESC
NVP/LPV/r/3TC
