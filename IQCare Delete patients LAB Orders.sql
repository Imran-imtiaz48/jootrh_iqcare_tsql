-- DECLARE @PatientId as INT = 2124
DECLARE @PatientMasterVisitId as INT = 250134

--select * from PatientIdentifier WHERE IdentifierValue LIKE '%20692%'
-- 31027

-- select * from gcPatientView WHERE EnrollmentNumber LIKE '%00961%'

--select * from PatientMasterVisit WHERE id = 254265

--select * from dtl_LabOrderTestResult WHERE LabOrderId = 213891
--select * from PatientLabTracker WHERE PatientId = 2821
--update PatientLabTracker SET DeleteFlag = 1 WHERE PatientMasterVisitId = 126135
--pmvi = 126135
-- order id = 213891
/*
DELETE FROM dtl_LabOrderTestResult  WHERE LabOrderId IN (SELECT ID FROM ord_LabOrder WHERE PatientId  = @PatientId)
DELETE FROM dtl_LabOrderTest WHERE LabOrderId IN (SELECT ID FROM ord_LabOrder WHERE PatientId  = @PatientId)
DELETE FROM ord_LabOrder WHERE PatientId  = @PatientId
DELETE FROM PatientLabTracker WHERE PatientId  = @PatientId
*/

-- select * from PatientMasterVisit where id = 239891
/*
delete from PatientEncounter WHERE id IN (
	select /*i.DisplayName,e.**/ e.id from PatientEncounter e INNER JOIN LookupItem i ON e.EncounterTypeId = i.id 
	LEFT JOIN ord_LabOrder o ON o.PatientId = e.PatientId AND o.PatientMasterVisitId = e.PatientMasterVisitId
	WHERE i.id <> 1482 AND i.id = 1503 AND o.Id IS NULL
)
*/
-- select * from ord_LabOrder WHERE PatientMasterVisitId = 239891
--select * from dtl_LabOrderTestResult WHERE LabOrderId = 239139

--select * from PatientLabTracker WHERE PatientMasterVisitId = 239891

--delete from dtl_LabOrderTestResult WHERE id = 195957
--delete from PatientLabTracker WHERE id = 42813

-- update ord_LabOrder SET OrderStatus = 'Pending' WHERE PatientMasterVisitId = 178506
-- ================================
-- LAB
DELETE FROM dtl_LabOrderTestResult  WHERE LabOrderId IN (SELECT ID FROM ord_LabOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId/* AND DeleteFlag = 1*/)
DELETE FROM dtl_LabOrderTest WHERE LabOrderId IN (SELECT ID FROM ord_LabOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId/* AND DeleteFlag = 1*/)
DELETE FROM ord_LabOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId -- AND DeleteFlag = 1
DELETE FROM PatientLabTracker WHERE PatientMasterVisitId  = @PatientMasterVisitId -- AND DeleteFlag = 1

DELETE FROM PatientEncounter WHERE EncounterTypeId = 1503 AND PatientMasterVisitId = @PatientMasterVisitId
--===========================*/
return

--SELECT PatientId FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId = @PatientMasterVisitId
-- Pharmacy Undispense
--UPDATE dtl_RegimenMap SET DeleteFlag = 1 where orderid = (SELECT ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId)
--DELETE FROM dtl_RegimenMap where orderid = (SELECT ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId)
--UPDATE dtl_PatientPharmacyOrder SET DispensedQuantity = 0 WHERE ptn_pharmacy_pk =  (SELECT ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId)
--UPDATE  ord_PatientPharmacyOrder SET DispensedByDate = NULL, DispensedBy = NULL, orderstatus = 1   WHERE PatientMasterVisitId = @PatientMasterVisitId


-- Pharmacy
DELETE FROM dtl_PatientPharmacyOrder  WHERE ptn_pharmacy_pk IN (SELECT ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId)
DELETE FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId
DELETE FROM dtl_RegimenMap where orderid = (SELECT ptn_pharmacy_pk FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId  = @PatientMasterVisitId)

DELETE FROM PatientEncounter WHERE EncounterTypeId = 1504 AND PatientMasterVisitId = @PatientMasterVisitId

-- SELECT * FROM LookupItemView WHERE MasterName LIKE '%EncounterType%'
/*
select * from PatientMasterVisit WHERE id = @PatientMasterVisitId

select * from LookupItemView WHERE ItemId = 1504
 
INSERT INTO [dbo].[PatientEncounter]
           ([PatientId]
           ,[EncounterTypeId]
           ,[PatientMasterVisitId]
           ,[EncounterStartTime]
           ,[EncounterEndTime]
           ,[ServiceAreaId]
           ,[DeleteFlag]
           ,[Status]
           ,[CreatedBy]
           ,[CreateDate]
           ,[AuditData])
     VALUES
           (33234
           ,1482
           ,178960
           ,'2019-02-05 13:54:19.583'
           ,'2019-02-05 13:54:19.583'
           ,1
           ,0
           ,0
           ,22
           ,'2019-02-05 13:54:19.583',
		   NULL)
GO

*/