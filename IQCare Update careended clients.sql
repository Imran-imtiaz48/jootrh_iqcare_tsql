-- select * from FacilityList where name like '%pand pieri%'

DECLARE @ccc AS NVARCHAR(15) = '24027'
	
select * from gcPatientView WHERE EnrollmentNumber LIKE '%19019%'

select * from patientcareending where patientId IN (select ID from gcPatientView WHERE EnrollmentNumber LIKE '%19019-10%')


select * from dtl_PatientCareEnded where Ptn_pk  IN (select ptn_pk from gcPatientView WHERE EnrollmentNumber LIKE '%19019-10%')


delete from dtl_PatientCareEnded   where Ptn_pk  IN (select ptn_pk from gcPatientView WHERE EnrollmentNumber LIKE '%19019-10%')


select * from PatientEnrollment WHERE PatientId = 4340

christine akoth omondi



select * from gcPatientView2 WHERE EnrollmentNumber LIKE '%20333%'

select * from gcPatientView WHERE EnrollmentNumber LIKE '%19019%'


-- 4340
Update pe 
Set CareEnded = 1
FROM
PatientCareending pce INNER JOIN PatientEnrollment pe on pce.PatientId = pe.PatientId AND pce.DeleteFlag = 0 and pe.CareEnded = 0 --and pce.PatientId = 4340


SELECT pce.*, pe.CareEnded from PatientCareending pce INNER JOIN PatientEnrollment pe on pce.PatientId = pe.PatientId AND pce.DeleteFlag = 0 and pe.CareEnded = 0 --and pce.PatientId = 4340

-- exec sp_MergePatientData @preferredPatientId=3709, @unpreferredPatientId = 9214 