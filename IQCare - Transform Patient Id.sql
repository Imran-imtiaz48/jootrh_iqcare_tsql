select * from PatientIdentifier WHERE PatientId = 12131


update PatientIdentifier SET IdentifierValue = '13029-00003' WHERE PatientId = 12131

select * from gcPatientView WHERE Id IN ( 10236,10327)


/*
update patient set DeleteFlag = 0 WHERE Id = 12131

update Person set DeleteFlag = 0 WHERE Id = (SELECT PersonId FROM Patient WHERE Id = 12131)

update mst_Patient SET DeleteFlag = 1 WHERE Ptn_Pk = ((SELECT Ptn_Pk FROM Patient WHERE Id = 8742))
*/

 /*
select top 100 
	SUBSTRING(IdentifierValue,CHARINDEX('-',IdentifierValue,1)+1, LEN(IdentifierValue)) as Index1,
	SUBSTRING(IdentifierValue,1, CHARINDEX('-',IdentifierValue,1)-1) as Index2,
	CONCAT(SUBSTRING(IdentifierValue,CHARINDEX('-',IdentifierValue,1)+1, LEN(IdentifierValue)),'-',SUBSTRING(IdentifierValue,1, CHARINDEX('-',IdentifierValue,1)-1)) as Index3,
	IdentifierValue
	from PatientIdentifier 
WHERE CHARINDEX('-',IdentifierValue,1) = 3 AND IdentifierValue NOT LIKE '%TI%' AND IdentifierTypeId =1
--	AND IdentifierValue = '10-18291'

UPDATE PatientIdentifier SET IdentifierValue = CONCAT(SUBSTRING(IdentifierValue,CHARINDEX('-',IdentifierValue,1)+1, LEN(IdentifierValue)),'-',SUBSTRING(IdentifierValue,1, CHARINDEX('-',IdentifierValue,1)-1))
WHERE CHARINDEX('-',IdentifierValue,1) = 3 AND IdentifierValue NOT LIKE '%TI%' AND IdentifierTypeId =1
--	AND IdentifierValue = '09-17370'

	select * from PatientIdentifier WHERE IdentifierValue = '17370-09' OR IdentifierValue = '09-17370'

*/


select * from PatientIdentifier WHERE IdentifierValue LIKE '%25973%'

select * from PatientIdentifier WHERE PatientId IN (10236,10327)

select * from Patient WHERE Id IN ( 10236,10327)


select * from PatientMergingLog WHERE PreferredPatientId = 10236 OR UnPreferredPatientId = 10236


select * from mst_User WHERE UserID =63