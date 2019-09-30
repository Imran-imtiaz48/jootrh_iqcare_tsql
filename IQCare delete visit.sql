declare @patientId as int  = 2000
declare @patientMasterVisitId as int  = 241370

-- select PatientId from PatientMasterVisit WHERE id = 241370





-- select * from Mst_Drug WHERE DrugName LIKE '%cotri%' and DeleteFlag = 0

-- select PatientId from PatientMasterVisit WHERE id = 169681
-- select * from PatientMasterVisit WHERE id =178579 -- 23-Jan-2009
/*

delete from PatientAppointment where PatientId = @patientId

delete from PatientClinicalNotes WHERE patientId = @patientId

delete from PatientFamilyPlanningMethod where PatientId = @patientId

delete from PatientPregnancyIntentionAssessment where PatientId = @patientId

delete from PatientPIAPregnancySymptom where PatientId = @patientId

delete from ARVTreatmentTracker where patientId  = @patientId

delete from PatientScreening WHERE patientId = @patientId

delete from PregnancyIndicator WHERE PatientId = @patientId

delete from PatientFamilyPlanningMethod WHERE patientId = @patientId

delete from PatientFamilyPlanning WHERE patientId = @patientId

delete from PatientMasterVisit WHERE patientId = @patientId

delete from PresentingComplaints WHERE patientId = @patientId

delete from PatientIcf  WHERE patientId = @patientId

delete from PatientChronicIllness WHERE patientId = @patientId

delete from PhysicalExamination WHERE patientId = @patientId

delete from PatientWHOStage WHERE patientId = @patientId

*/
-- select * from gcPatientView WHERE EnrollmentNumber = '10003/00' 14148 (10003/00)


delete from PatientAppointment where PatientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientClinicalNotes WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientPIAPregnancySymptom where PatientId = @patientId and PatientPIAId IN (SELECT ID FROM PatientPregnancyIntentionAssessment where PatientId = @patientId  and PatientMasterVisitId = @patientMasterVisitId)

delete from PatientPregnancyIntentionAssessment where PatientId = @patientId  and PatientMasterVisitId = @patientMasterVisitId

delete from ARVTreatmentTracker where patientId  = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientScreening WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PregnancyIndicator WHERE PatientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientFamilyPlanningMethod WHERE patientId = @patientId and PatientFPId IN (SELECT ID FROM PatientFamilyPlanning WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId)

delete from PatientFamilyPlanning WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PresentingComplaints WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientIcf  WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientIpt WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientIptOutcome WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientIptWorkup WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientChronicIllness WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PhysicalExamination WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientWHOStage WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientEncounter WHERE patientId = @patientId and PatientMasterVisitId = @patientMasterVisitId

delete from PatientMasterVisit WHERE patientId = @patientId and id = @patientMasterVisitId

delete from dtl_PatientPharmacyOrder WHERE ptn_pharmacy_pk IN (select ptn_pharmacy_pk from ord_PatientPharmacyOrder WHERE PatientId = @patientId AND PatientMasterVisitId = @patientMasterVisitId)

delete from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = @patientMasterVisitId AND PatientId = @patientId


-- DLETE ALL REGIMEN DATA
/*


delete * from ARVTreatmentTracker WHERE PatientMasterVisitId = @PatientMasterVisitId

DELETE from dtl_RegimenMap WHERE OrderId = (select ptn_pharmacy_pk from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = @PatientMasterVisitId)
DELETE FROM dtl_PatientPharmacyOrder  WHERE ptn_pharmacy_pk = (select ptn_pharmacy_pk from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = @PatientMasterVisitId)
select * from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = 169150
*/