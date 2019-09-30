-- Update Mst PatientTable
/*
UPDATE 
mp
SET 
mp.PatientEnrollmentID = gc.ENrollmentNUmber
-- SELECT * 
FROM
	mst_Patient mp LEFT JOIN gcPatientView2 gc ON  mp.Ptn_Pk = gc.ptn_pk
WHERE gc.EnrollmentNumber <> mp.PatientEnrollmentID
AND PatientEnrollmentID = '13939-26050'
*/
UPDATE m
SET m.PatientEnrollmentID = p.EnrollmentNumber
--SELECT PatientEnrollmentID , EnrollmentNumber
FROM mst_patient m INNER JOIN
(
	SELECT gc.ptn_pk, gc.id, gc.EnrollmentNumber 
	FROM
		gcPatientView2 gc LEFT JOIN mst_Patient mp ON  mp.Ptn_Pk = gc.ptn_pk AND mp.PatientEnrollmentID = gc.EnrollmentNumber
	WHERE mp.Ptn_Pk IS NULL
--	AND gc.EnrollmentNumber = 'PREP-13939-00156'
) p ON p.ptn_pk = m.Ptn_Pk
