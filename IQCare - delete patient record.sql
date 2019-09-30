/*
declare @ptn_pk as nvarchar(max) = 12907

delete from mst_Patient WHERE Ptn_Pk IN (@ptn_pk)

delete from ServiceEntryPoint WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

delete from PatientIdentifier WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

delete from patient where Ptn_Pk IN (@ptn_pk)
*/

-- SOFT DELETE

declare @ptn_pk as nvarchar(max) -- = 8600

select @ptn_pk = ptn_pk from gcPatientView WHERE enrollmentNumber IN ( '13576','13715','13788'
,'13953','13962','13971','14024','14031',
'13671',
'13721',
'13827',
'13835',
'13579',
'13580',
'13939-99995','22819/12','13663','00154','13641','00045','13939-13837','TI-00649-15','00055'

)

--print @ptn_pk

UPDATE mst_Patient SET DeleteFlag = 1 WHERE Ptn_Pk IN (@ptn_pk)

UPDATE ServiceEntryPoint SET DeleteFlag = 1 WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

UPDATE PatientIdentifier SET DeleteFlag = 1 WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

UPDATE patient SET DeleteFlag = 1 where Ptn_Pk IN (@ptn_pk)

select * from gcPatientView WHERE enrollmentNumber IN ( '13576','13715','13788'
,'13953','13962','13971','14024','14031',
'13671',
'13721',
'13827',
'13835',
'13579',
'13580',
'13939-99995','22819/12','13663','00154','13641','00045','13939-13837','TI-00649-15','00055'
)


/*
-- HARD DELETE


declare @ptn_pk as nvarchar(max) -- = 8600

select @ptn_pk = ptn_pk from gcPatientView WHERE enrollmentNumber IN ( '13939-12345'
)

DELETE FROM mst_Patient WHERE Ptn_Pk IN (@ptn_pk)

DELETE FROM ServiceEntryPoint WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

DELETE FROM PatientIdentifier WHERE PatientId IN (Select id from patient WHERE Ptn_Pk IN (@ptn_pk))

DELETE FROM patient where Ptn_Pk IN (@ptn_pk)

--select * from gcPatientView WHERE EnrollmentNumber LIKE '%prep%'
*/