select * from PatientPregnancyIntentionAssessment WHERE PatientId = 100


select * from PatientFamilyPlanning WHERE PatientMasterVisitId =153194


SELECT * FROM gcPatientView WHERE EnrollmentNumber LIKE '%17362%'


SELECT * FROM PatientAppointment WHERE PatientId = 5198 order by id DESC


select * from PatientMasterVisit WHERE id = 178626


SELECT v.PatientId, v.VisitDate, p.AppointmentDate,DATEDIFF(MONTH, v.VisitDate, p.AppointmentDate) as dif, p.CreateDate, p.CreatedBy FROM PatientMasterVisit v INNER JOIN PatientAppointment p ON v.PatientId = p.PatientId AND v.id = p.PatientMasterVisitId
WHERE DATEDIFF(MONTH, v.VisitDate, p.AppointmentDate) > 6 AND YEAR(p.CreateDate) = 2019  AND p.CreatedBy > 0
ORDER BY CReateDate DESC


-- To correct seemingly mismatched Appointment Dates
-----------------------------------------------------
-- Get the date
--	Reverse the date and month
--		Check if valid date
--			Check if difference with VisitDate is < 6 MOnths
--				If so, update it
--				If not, Take year of visit date and use with the appointment's date and month.
--					Check if valid date
--					Check if difference is < 6 months
--						If so, update it
--				If not, Take year of visit date, and combine with reversed appointment date
--					Check if valid date
--					Check if difference is < 6 months
--						If so, update it
--				if not, add 3 months to the visit date and get the year, combine the year with the appointment's date and month
--					Check if valid date
--					Check if difference is < 6 months
--						If so, update it
--				if not, add 3 months to the visit date and get the year, combine the year with reversed appointment's date and month
--					Check if valid date
--					Check if difference is < 6 months
--						If so, update it
									




