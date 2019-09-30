select * from ord_PatientPharmacyOrder WHERE PatientMasterVisitId = 90053
select * from dtl_PatientPharmacyOrder WHERE ptn_pharmacy_pk = 186138
select  * from ord_Visit WHERE Visit_Id = 721828
select * from gcPatientView2  WHERE EnrollmentNumber LIKE '%22326%'
select * from PatientIdentifier WHERE IdentifierValue LIKE '%11443%'
select * from gcPatientView WHERE Id = 3659
select * from PatientIdentifier WHERE PatientId = 3659

select * from mst_Patient WHERE Ptn_Pk =3660

exec sp_MergePatientData 3659, 370

select * from PatientMergingLog WHERE PreferredPatientId = 3659 or UnPreferredPatientId = 3659


select * from PatientIdentifier WHERE PatientId = 370

 select * from VW_PatientPharmacy where Ptn_pk = 3828 order by OrderedByDate desc


-- select * from PatientIdentifier WHERE IdentifierValue = '' order by createDate DESC


-- DELETE FROM PatientIdentifier WHERE Id = 14105 and IdentifierValue = ''


