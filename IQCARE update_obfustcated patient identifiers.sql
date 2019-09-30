UPDATE d SET d.FirstName = s.firstName FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.LastName = s.LastName FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.MiddleName = s.MiddleName FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.[Address] = s.[Address] FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.[Phone] = s.[phone] FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.[DobPrecision] = s.[DobPrecision] FROM [IQCare_CPAD1].[dbo].mst_patient s INNER JOIN [IQCare_CPAD].[dbo].mst_patient d ON s.Ptn_Pk = d.Ptn_Pk

UPDATE d SET d.FirstName = s.firstName FROM [IQCare_CPAD1].[dbo].person s INNER JOIN [IQCare_CPAD].[dbo].person d ON s.id = d.id

UPDATE d SET d.LastName = s.LastName FROM [IQCare_CPAD1].[dbo].person s INNER JOIN [IQCare_CPAD].[dbo].person d ON s.id = d.id

UPDATE d SET d.MidName = s.MidName FROM [IQCare_CPAD1].[dbo].person s INNER JOIN [IQCare_CPAD].[dbo].person d ON s.id = d.id


UPDATE d SET d.UserLastName = s.UserLastName FROM [IQCare_CPAD1].[dbo].mst_User s INNER JOIN [IQCare_CPAD].[dbo].mst_User d ON s.UserID = d.UserID

UPDATE d SET d.UserFirstName = s.UserFirstName FROM [IQCare_CPAD1].[dbo].mst_User s INNER JOIN [IQCare_CPAD].[dbo].mst_User d ON s.UserID = d.UserID

UPDATE d SET d.MobileNumber = s.MobileNumber FROM [IQCare_CPAD1].[dbo].PersonContact s INNER JOIN [IQCare_CPAD].[dbo].PersonContact d ON s.id = d.id

UPDATE d SET d.FirstName = s.FirstName, d.LastName = s.LastName FROM [IQCare_CPAD1].[dbo].mst_employee s INNER JOIN [IQCare_CPAD].[dbo].mst_employee d ON s.EmployeeID = d.EmployeeID

UPDATE d SET d.GuardianName = s.GuardianName, d.GuardianInformation = s.GuardianInformation, d.EmergContactName = s.EmergContactName, d.EmergContactPhone = s.EmergContactPhone, d.EmergContactAddress = s.EmergContactAddress, d.TenCellLeader = s.TenCellLeader, d.TreatmentSupporterName = s.TreatmentSupporterName, d.CommunitySupportGroup = s.CommunitySupportGroup, d.TreatmentSupportAddress = s.TreatmentSupportAddress FROM [IQCare_CPAD1].[dbo].dtl_PatientContacts s INNER JOIN [IQCare_CPAD].[dbo].dtl_PatientContacts d ON s.ptn_pk = d.ptn_pk AND s.LocationID = d.LocationID


SELECT * FROM [IQCare_CPAD].[dbo].mst_Patient WHERE ptn_pk = 6990

SELECT * FROM [IQCare_CPAD1].[dbo].mst_Patient WHERE ptn_pk = 6990

SELECT * from [IQCare_CPAD].dbo.person WHERE id= 1

SELECT * from [IQCare_CPAD1].dbo.person WHERE id =1
