/* AND  */
exec pr_OpenDecryptedSession
go
WITH appointments_CTE AS
(
SELECT			Patient.Id as PatientId, 
				Patient.ptn_pk,
				Patient.PersonId,
				Patient.FirstName,
				Patient.LastName,
				Patient.MobileNumber,
				Patient.[EnrollmentDate ],
				Patient.EnrollmentNumber,
				Patient.PatientStatus,
				Patient.DateOfBirth, 
				lastAppointment.TCADate, 
				lastVisit.lastVisit, 
				DATEDIFF(dd, lastVisit.lastVisit, lastAppointment.TCADate) AS DaysBtwLastVisitAndTCADate
FROM            gcPatientView AS Patient INNER JOIN
                             (SELECT        PatientId, MAX(VisitDate) AS lastVisit
                               FROM            PatientMasterVisit
                               WHERE        (VisitDate IS NOT NULL) AND (DeleteFlag = 0)
                               GROUP BY PatientId) AS lastVisit ON Patient.Id = lastVisit.PatientId LEFT OUTER JOIN
								(SELECT PatientId, MAX(AppointmentDate) as TCADate FROM 
									(
										SELECT        PatientId, AppointmentDate
										FROM            PatientAppointment
										WHERE        (DeleteFlag = 0) AND (ServiceAreaId = 255) AND (AppointmentDate <= '2018-01-31')
										
									) As appointments GROUP BY	appointments.PatientId							   
								   ) AS lastAppointment ON Patient.Id = lastAppointment.PatientId
WHERE Patient.PatientStatus = 'Active'
),

locator_CTE AS (
		SELECT        PersonId, Location, SubLocation, Village, LandMark, NearestHealthCentre
		FROM            PersonLocation AS L
)
--Link to lastStatus (PatientCareEnding)
SELECT 
	a.PersonId,
	a.ptn_pk,
	a.FirstName, 
	a.LastName, 
	a.[EnrollmentDate ], 
	a.EnrollmentNumber,
	a.PatientStatus, 
	a.DateOfBirth, 
	a.TCADate,
	a.lastVisit,
	l.*,
	a.DaysBtwLastVisitAndTCADate	 
FROM appointments_CTE a 
LEFT OUTER JOIN locator_CTE l ON a.PersonId = l.PersonId
WHERE a.DaysBtwLastVisitAndTCADate > = 90  
-- AND l.PersonId IS  NULL
-- AND year(lastVisit) =2017

-- SELECT * FROM PersonLocation WHERE PersonId = 16038
