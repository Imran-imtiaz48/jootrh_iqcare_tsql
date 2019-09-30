-- select * from gcPatientView2 where EnrollmentNumber = '13939-27027'


SELECT        u.UserLastName, u.UserFirstName, pe.PatientId, pe.EnrollmentDate, pe.CreateDate, gcPatientView2.[EnrollmentNumber] ,gcPatientView2.PatientType
FROM            PatientEnrollment AS pe INNER JOIN
                         mst_User AS u ON pe.CreatedBy = u.UserID INNER JOIN
                         gcPatientView2 ON pe.PatientId = gcPatientView2.Id
WHERE
        EnrollmentNumber = '14007-00036'
pe.PatientId IN (
31377,
31378,
31380,
31381,
31457,
31458,
31467,
31534,
31535,
31539,
31540,
31546,
31551,
31603,
31607,
31610

)

UPDATE patient SET PatientType = 258 WHERE id IN (
	31377,
	31378,
	31380,
	31381,
	31457,
	31458,
	31467,
	31534,
	31535,
	31539,
	31540,
	31546,
	31551,
	31603,
	31607,
	31610
)
-- select * from mst_Patient m