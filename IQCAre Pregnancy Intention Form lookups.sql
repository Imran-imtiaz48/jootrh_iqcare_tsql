-- Pregnancy Symptoms
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'PregnancySymptoms')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('PregnancySymptoms','Pregnancy Symptoms')
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Spotting')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('S','Spotting',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Nausea/vomiting')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('NAUSEA','Nausea/vomiting',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Tenderness')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('FATIGUE','Fatigue/tiredness/weakness',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Tenderness')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('FATIGUE','Fatigue/tiredness/weakness',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'NONE')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('NONE','NONE',0)
		

DECLARE @pregnancySymptoms INT 
SELECT @pregnancySymptoms = id from LookupMaster WHERE Name = 'PregnancySymptoms'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @pregnancySymptoms AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Nausea/vomiting'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@pregnancySymptoms,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Nausea/vomiting'),'Nausea and Vomitting',1)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @pregnancySymptoms AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Tenderness'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@pregnancySymptoms,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Tenderness'),'Breast Tenderness',2)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @pregnancySymptoms AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Tenderness'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@pregnancySymptoms,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Tenderness'),'Unusual Tiredness',3)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @pregnancySymptoms AND LookupItemId = (SELECT id FROM LookupItem WHERE DisplayName = 'Spotting'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@pregnancySymptoms,(SELECT id FROM LookupItem WHERE DisplayName = 'Spotting'),'Spotting',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @pregnancySymptoms AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'NONE'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@pregnancySymptoms,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'NONE'),'None',5)

--Partner HIV Status
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'PartnerHIVStatus')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('PartnerHIVStatus','Partner HIV Status')
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Known Positive')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('KP','Known Positive',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Positive')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Positive','Positive',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Negative')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Negative','Negative',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Unknown')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('Unknown','Unknown',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Not Applicable')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('NotApplicable','Not Applicable',0)

DECLARE @partnerHIVStatus INT 
SELECT @partnerHIVStatus = id from LookupMaster WHERE Name = 'PartnerHIVStatus'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @partnerHIVStatus AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Positive'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@partnerHIVStatus,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Positive'),'Positive',1)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @partnerHIVStatus AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Negative'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@partnerHIVStatus,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Negative'),'Negative',2)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @partnerHIVStatus AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Known Positive'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@partnerHIVStatus,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Known Positive'),'Known Positive',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @partnerHIVStatus AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Unknown'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@partnerHIVStatus,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Unknown'),'Unknown or Not Tested',5)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @partnerHIVStatus AND LookupItemId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Not Applicable'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@partnerHIVStatus,(SELECT top 1 Id FROM LookupItem WHERE DisplayName = 'Not Applicable'),'Not Applicable',0)
GO

--FP Services Offered
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'FpServiceOffered')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('FpServiceOffered','Family Planning Services Offered')

IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Accepted or provided Family Planning')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('ACCEPTEDFP','Accepted or provided Family Planning',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Counselled on Family Planning method')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('COUNSELLEDFPMETH','Counselled on Family Planning method',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Currently on Family Planning method')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('CURRENTLYONFPMETH','Currently on Family Planning method',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Declined Family Planning method')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('DECLINEDFPMETH','Declined Family Planning method',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Referred for Family Planning method')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('REFERREDFPMETH','Referred for Family Planning method',0)

DECLARE @fpServices INT 
SELECT @fpServices = id from LookupMaster WHERE Name = 'FpServiceOffered'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpServices AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'ACCEPTEDFP'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpServices,(SELECT top 1 id FROM LookupItem WHERE Name = 'ACCEPTEDFP'),'Accepted or provided Family Planning',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpServices AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'COUNSELLEDFPMETH'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpServices,(SELECT top 1 id FROM LookupItem WHERE Name = 'COUNSELLEDFPMETH'),'Counselled on Family Planning method',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpServices AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'DECLINEDFPMETH'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpServices,(SELECT top 1 id FROM LookupItem WHERE Name = 'DECLINEDFPMETH'),'Declined Family Planning method',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpServices AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'REFERREDFPMETH'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpServices,(SELECT top 1 id FROM LookupItem WHERE Name = 'REFERREDFPMETH'),'Referred for Family Planning method',4)
GO

-- FP Ineligibility Reason
IF NOT EXISTS (SELECT * FROM LookupMaster WHERE Name = 'FpIneligibilityReason')
	INSERT INTO LookupMaster (Name,DisplayName) VALUES('FpIneligibilityReason','Reason for ineligibility of Family Planning')

IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Hysterectomy')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('HYSTERECTOMY','Hysterectomy',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Menopausal')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('MENOPAUSAL','Menopausal',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Sexually Inactive')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('SEXINACTIVE','Sexually Inactive',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Currently Pregnant')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('CurrentlyPregnant','Currently Pregnant',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Currently Pregnant')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('CurrentlyPregnant','Currently Pregnant',0)
IF NOT EXISTS (SELECT * FROM LookupItem WHERE DisplayName = 'Currently on FP method')
	INSERT INTO LookupItem (Name,DisplayName,DeleteFlag) VALUES ('CurrentlyOnFP','Currently ON FP method',0)

DECLARE @fpIneligibility INT 
SELECT @fpIneligibility = id from LookupMaster WHERE Name = 'FpIneligibilityReason'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'CURRENTLYONFPMETH'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE Name = 'CURRENTLYONFPMETH'),'Currently on Family Planning method',1)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE Name = 'DECLINEDFPMETH'))
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Currently Pregnant'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Currently Pregnant'),'Currently Pregnant',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Hysterectomy'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Hysterectomy'),'Hysterectomy',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Menopausal'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Menopausal'),'Menopausal',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Sexually Inactive'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Sexually Inactive'),'Sexually Inactive',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Tubal Ligation /Female Sterilization'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Tubal Ligation /Female Sterilization'),'Tibal Ligation',4)
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @fpIneligibility AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Vasectomy'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@fpIneligibility,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Vasectomy'),'Partner has vasectomy',4)


DECLARE @nofp INT 
SELECT @nofp = id from LookupMaster WHERE Name = 'NoFamilyPlanning'

IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Currently Pregnant'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Currently Pregnant'),'Currently Pregnant',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Hysterectomy'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Hysterectomy'),'Hysterectomy',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Menopausal'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Menopausal'),'Menopausal',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))
--IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Sexually Inactive'))
--	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Sexually Inactive'),'Sexually Inactive',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Tubal Ligation /Female Sterilization'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Tubal Ligation /Female Sterilization'),'Tibal Ligation',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))
IF NOT EXISTS (SELECT * FROM LookupMasterItem WHERE LookupMasterId = @nofp AND LookupItemId = (SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Vasectomy'))
	INSERT INTO LookupMasterItem (LookupMasterId,LookupItemId,DisplayName,OrdRank) VALUES (@nofp,(SELECT top 1 id FROM LookupItem WHERE DisplayName = 'Vasectomy'),'Partner has vasectomy',(SELECT ISNULL(MAX(OrdRank),0)+1 FROM LookupMasterItem WHERE LookupMasterId = @nofp))


