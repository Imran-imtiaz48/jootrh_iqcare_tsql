SELECT IdentifierValue, LEFT(IdentifierValue,5),RIGHT(IdentifierValue,5), CHARINDEX('/',IdentifierValue,1)   FROM PatientIdentifier 
WHERE IdentifierTypeId = (select Id from Identifiers where code='CCCNumber')
AND LEN(IdentifierValue) = 10 AND ISNUMERIC(IdentifierValue) = 1



UPDATE PatientIdentifier SET IdentifierValue = CONCAT(LEFT(IdentifierValue,5),'-',RIGHT(IdentifierValue,5))
WHERE IdentifierTypeId = (select Id from Identifiers where code='CCCNumber')
AND LEN(IdentifierValue) = 10 AND ISNUMERIC(IdentifierValue) = 1


SELECT IdentifierValue, LEFT(IdentifierValue,5),RIGHT(IdentifierValue,5), CHARINDEX('/',IdentifierValue,1)   FROM PatientIdentifier 
WHERE IdentifierTypeId = (select Id from Identifiers where code='CCCNumber')
AND LEN(IdentifierValue) = 11

