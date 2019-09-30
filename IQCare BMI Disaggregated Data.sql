SELECT [Period], 
gender, 
count(*) as count FROM (
	SELECT b.EnrollmentDate,CASE WHEN g.Sex = 52 THEN 'Female' ELSE 'Male' END as gender,
		CASE 
			WHEN b.EnrollmentDate BETWEEN '2014-07-01' AND '2015-06-30' THEN '2014/2015'
			WHEN b.EnrollmentDate BETWEEN '2015-07-01' AND '2016-06-30' THEN '2015/2016'
			WHEN b.EnrollmentDate BETWEEN '2016-07-01' AND '2017-06-30' THEN '2016/2017'
			WHEN b.EnrollmentDate BETWEEN '2017-07-01' AND '2018-06-30' THEN '2017/2018'
		END 
		AS Period
	 FROM PatientBaselineView b
	 INNER JOIN (
		SELECT        Person.Sex, Patient.Id  as PatientId
		FROM            Person INNER JOIN
								 Patient ON Person.Id = Patient.PersonId 			 
	 ) g ON b.PatientId = g.PatientId
	 WHERE b.EnrollmentDate BETWEEN '2014-07-01' AND '2018-06-30' AND BMI > 25
) as N GROUP BY N.[Period],gender
