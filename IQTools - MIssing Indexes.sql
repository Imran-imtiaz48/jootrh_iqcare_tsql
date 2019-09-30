/*
Missing Index Details from SQLQuery2.sql - DESKTOP-N4D22DU\SQLEXPRESS01.IQTools_KeHMIS (sa (72))
The Query Processor estimates that implementing the following index could improve the query cost by 23.5998%.
*/


USE [IQTools_KeHMIS]
GO
--DROP INDEX [IX_tmp_Pharmacy_DispenseDate_TreatmentType__ExpectedReturn] ON [dbo].[tmp_Pharmacy]
--DROP INDEX [IX_tmp_Pharmacy_DispenseDate_TreatmentType_Duration] ON [dbo].[tmp_Pharmacy]
--DROP INDEX [IX_tmp_Pharmacy_ProphylaxisType_Drug] ON [dbo].[tmp_Pharmacy]
--DROP INDEX [IX_tmp_PatientMaster_PatientType_RegistrationAtCCC_AgeEnrollment] ON [dbo].[tmp_PatientMaster]
--DROP INDEX [IX_tmp_ClinicalEncounters_PwP_VisitDate] ON [dbo].[tmp_ClinicalEncounters]
--DROP INDEX [IX_tmp_ClinicalEncounters_VisitDate_FamilyPlanningMethod] ON [dbo].[tmp_ClinicalEncounters]

CREATE NONCLUSTERED INDEX [IX_tmp_Pharmacy_DispenseDate_TreatmentType__ExpectedReturn]
ON [dbo].[tmp_Pharmacy] ([DispenseDate],[TreatmentType])
INCLUDE ([ExpectedReturn])
GO

CREATE NONCLUSTERED INDEX [IX_tmp_PatientMaster_PatientType_RegistrationAtCCC_AgeEnrollment]
ON [dbo].[tmp_PatientMaster] ([PatientType],[RegistrationAtCCC],[AgeEnrollment])
INCLUDE ([PatientSource])
GO

CREATE NONCLUSTERED INDEX [IX_tmp_ClinicalEncounters_PwP_VisitDate]
ON [dbo].[tmp_ClinicalEncounters] ([PwP],[VisitDate])

go

CREATE NONCLUSTERED INDEX [IX_tmp_Pharmacy_DispenseDate_TreatmentType_Duration]
ON [dbo].[tmp_Pharmacy] ([DispenseDate],[TreatmentType])
INCLUDE ([Duration])
go
CREATE NONCLUSTERED INDEX [IX_tmp_Pharmacy_ProphylaxisType_Drug]
ON [dbo].[tmp_Pharmacy] ([ProphylaxisType],[Drug])
INCLUDE ([DispenseDate])
go
CREATE NONCLUSTERED INDEX [IX_tmp_ClinicalEncounters_VisitDate_FamilyPlanningMethod]
ON [dbo].[tmp_ClinicalEncounters] ([VisitDate],[FamilyPlanningMethod])

