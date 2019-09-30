UPDATE 
pid
SET 
	pid.IdentifierValue = spid.StandardCCCNo, 
	pid.IdentifierOld = spid.IdentifierValue
FROM PatientIdentifier pid
INNER JOIN 
 (
	SELECT 
		gc.Id, gc.IdentifierValue --, gc.IdentifierOld , PATINDEX('%-%',gc.IdentifierValue)
		 , CONCAT('13939-',
			 RIGHT(
				 CONCAT('00000',
					CASE WHEN PATINDEX('%-%',gc.IdentifierValue) = 3 THEN SUBSTRING(gc.IdentifierValue,PATINDEX('%-%',gc.IdentifierValue)+1,LEN(gc.IdentifierValue))
						WHEN PATINDEX('%/%',gc.IdentifierValue) = 3 THEN SUBSTRING(gc.IdentifierValue,PATINDEX('%/%',gc.IdentifierValue)+1,LEN(gc.IdentifierValue)) 
						WHEN PATINDEX('%-%',REVERSE(gc.IdentifierValue)) = 3 THEN SUBSTRING(gc.IdentifierValue,1, LEN(gc.IdentifierValue) - PATINDEX('%-%',REVERSE(gc.IdentifierValue))) 					
						WHEN PATINDEX('%/%',REVERSE(gc.IdentifierValue)) = 3 THEN SUBSTRING(gc.IdentifierValue,1, LEN(gc.IdentifierValue) - PATINDEX('%/%',REVERSE(gc.IdentifierValue))) 					
						END
				),
			  5)
		   ) [StandardCCCNo]
	FROM PatientIdentifier gc
	WHERE  LEN(gc.IdentifierValue) <= 8
	AND 
		(PATINDEX('%-%',gc.IdentifierValue) = 3 OR PATINDEX('%/%',gc.IdentifierValue) = 3 OR PATINDEX('%-%',REVERSE(gc.IdentifierValue)) = 3 OR PATINDEX('%/%',REVERSE(gc.IdentifierValue)) = 3) AND PATINDEX('%TI%',gc.IdentifierValue) = 0
	AND gc.IdentifierTypeId = 1
	-- AND IdentifierValue = '21010-11'
) AS spid ON pid.Id = spid.Id


--select  * from PatientIdentifier WHERE IdentifierValue LIKE '%ti-01017-17%' OR IdentifierValue LIKE '%TI-0008-12%' or identifierValue LIKE '%TI-00008-1%'

-- exec sp_MergePatientData 731,3984

-- update PatientIdentifier SET IdentifierValue = 'TI-00008-12' WHERE Id = 17352

-- delete from PatientIdentifier WHERE Id = 17350