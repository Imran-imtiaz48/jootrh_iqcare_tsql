-- PHARMACY
UPDATE ord
SET ord.PatientId = p.id
FROM ord_PatientPharmacyOrder ord
INNER JOIN (
	select o.ptn_pharmacy_pk, p.id, o.PatientId, o.Ptn_pk from ord_PatientPharmacyOrder o
	INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
	 where PatientId IS NULL
) p ON p.ptn_pharmacy_pk = ord.ptn_pharmacy_pk


-- LAB ORDER
UPDATE ord
SET ord.PatientId = p.id
FROM ord_LabOrder ord
INNER JOIN (
	select o.id, o.PatientId, o.Ptn_pk from ord_LabOrder o
	INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
	 where PatientId IS NULL
) p ON p.id = ord.id

-- UPDATE WRONGLY MAPPED PatientId Values
UPDATE ord 
SET ord.PatientId = p.cPatientId
FROM ord_LabOrder ord
INNER JOIN (
	select  o.id, o.Ptn_Pk,o.PatientId,p2.id cPatientId from ord_LabOrder o LEFT JOIN patient p on p.ptn_pk = o.Ptn_Pk AND o.PatientId = p.id
	INNER JOIN patient p2 ON p2.ptn_pk = o.Ptn_Pk
	WHERE p.id IS NULL
) p ON p.id = ord.Id
