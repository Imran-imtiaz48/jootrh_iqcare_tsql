SELECT PatientId,p2.ptn_pk as CorrectPtnPk, ord.Ptn_pk as WrongPtnPk  FROM ord_PatientPharmacyOrder ord LEFT JOIN patient p on ord.PatientId = p.id AND p.ptn_pk = ord.Ptn_pk 
INNER JOIN Patient p2 ON ord.PatientId = p2.id
INNER JOIN PatientMergingLog pml ON pml.PreferredPatientId = ord.PatientId OR pml.UnPreferredPatientId = ord.PatientId
WHERE p.id IS NULL AND PatientID IS NOT NULL


SELECT PatientId,p2.ptn_pk as CorrectPtnPk, ord.Ptn_pk as WrongPtnPk  FROM ord_LabOrder ord LEFT JOIN patient p on ord.PatientId = p.id AND p.ptn_pk = ord.Ptn_pk 
INNER JOIN Patient p2 ON ord.PatientId = p2.id
INNER JOIN PatientMergingLog pml ON pml.PreferredPatientId = ord.PatientId OR pml.UnPreferredPatientId = ord.PatientId
WHERE p.id IS NULL AND PatientID IS NOT NULL 


select PatientId from ord_LabOrder WHERE Ptn_Pk = 1061
update ord_LabOrder SET PatientId = 5780 WHERE Ptn_Pk =1061 AND PatientId IS NULL


select * from Patient where id = 5780

UPDATE Ord 
SET ord.Ptn_Pk = p2.Ptn_pk
FROM ord_PatientPharmacyOrder ord LEFT JOIN patient p on ord.PatientId = p.id AND p.ptn_pk = ord.Ptn_pk 
INNER JOIN Patient p2 ON ord.PatientId = p2.id
INNER JOIN PatientMergingLog pml ON pml.PreferredPatientId = ord.PatientId OR pml.UnPreferredPatientId = ord.PatientId
WHERE p.id IS NULL AND PatientID IS NOT NULL 

 
UPDATE Ord 
SET ord.Ptn_Pk = p2.Ptn_pk
FROM ord_LabOrder ord LEFT JOIN patient p on ord.PatientId = p.id AND p.ptn_pk = ord.Ptn_pk 
INNER JOIN Patient p2 ON ord.PatientId = p2.id
INNER JOIN PatientMergingLog pml ON pml.PreferredPatientId = ord.PatientId OR pml.UnPreferredPatientId = ord.PatientId
WHERE p.id IS NULL AND PatientID IS NOT NULL 


