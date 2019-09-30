UPDATE Patient SET PatientType = 257
WHERE ID IN (
SELECT ID FROM (
	select p.Id, IdentifierValue, p.PatientType from patient p
	INNER JOIN PatientIdentifier pid ON pid.PatientId = p.id
	WHERE PatientType = 258 AND IdentifierValue LIKE '%T%'
) pid)

-- ORDER BY Id DESc

select * from LookupItem WHERE Id = 257