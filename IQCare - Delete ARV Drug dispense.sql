select * from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = 196360

select * from ord_PatientPharmacyOrder WHERE ptn_pharmacy_pk = 224212

select * from dtl_PatientPharmacyOrder WHERE ptn_pharmacy_pk = 224212

-- delete from dtl_PatientPharmacyOrder WHERE ptn_pharmacy_pk = 224212 AND Drug_Pk IN (1702)

select * from dtl_RegimenMap WHERE Visit_Pk = 814508


update dtl_RegimenMap SET RegimenType = 'TDF/3TC/LPV/r'  WHERE Visit_Pk = 814508

-- delete from dtl_RegimenMap WHERE Visit_Pk = 795761
	
select * from mst_drug WHERE Drug_pk = 1702

select * from ARVTreatmentTracker WHERE PatientMasterVisitId = 196360

-- DELETE from ARVTreatmentTracker WHERE PatientMasterVisitId = 179985

