DECLARE @StartDate AS DATE = '20180701'
DECLARE @EndDate AS DATE = '20180930'

DECLARE @OldStartDate AS DATE = '20170701'
DECLARE @OldEndDate AS DATE = '20170701'


/*
-- Number of patients reinitiated (previously LTFU and brought back to care and not counted under Tx_New)?			
select Id, EnrollmentNumber as PatientId, [EnrollmentDate ],Sex, FirstName,LastName from gcPatientView2 WHERE id IN (
--2314
	select distinct PatientId/*, CAST(ReenrollmentDate AS DATE) as ReenrollmentDate*/ from PatientReenrollment WHERE ReenrollmentDate BETWEEN @Startdate and @EndDAte
) AND (ExitDate IS NULL OR ExitDate >= @startDate)
*/

--Number patients transferred in from another site 			
/*select * from gcPatientView WHERE PatientType = 257 AND EnrollmentDate BETWEEN @StartDate and @EndDate*/

-- Number of patients added to treatment count due to a data quality error or correction?			


-- Number who were LTFU?
--select * from gcPatientView WHERE EnrollmentDate BETWEEN @OldStartDate AND @OldEndDate



--select * from PatientReenrollment WHERE PatientId = 2314



-- select * from PatientEnrollment WHERE 


--select * from gcPatientView WHERE RegistrationDate < = '20180930' AND id IN (	
	select distinct  UnPreferredPatientId from PatientMergingLog WHERE CreateDate <= @EndDate
--)

select * from mst_Patient where PatientEnrollmentID is NOT null 

select DeleteFlag from mst_Patient WHERE PatientEnrollmentID LIKE '%18818-10%'

select * from patient WHERE ptn_pk IN (6065)

select * from gcPatientView WHERE ptn_pk IN (14216
,14217)





