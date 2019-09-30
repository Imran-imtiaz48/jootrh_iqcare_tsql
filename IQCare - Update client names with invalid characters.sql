exec pr_OpenDecryptedSession

UPDATE ps
SET 
ps.FirstName = p.EncryptedFirstName,
ps.MidName = p.EncryptedMidName,
ps.LastName = p.EncryptedLastName
FROM Person ps
INNER JOIN 
(
	SELECT id, UPPER(REPLACE( DECRYPTBYKEY(MidName), char(0),'')) AS PatientName
	, ENCRYPTBYKEY(KEY_GUID('Key_CTC'), UPPER(REPLACE( CAST(DECRYPTBYKEY(MidName) AS VARCHAR(50)), char(0),''))) AS EncryptedMidName 
	, ENCRYPTBYKEY(KEY_GUID('Key_CTC'), UPPER(REPLACE( CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)), char(0),''))) AS EncryptedFirstName 
	, ENCRYPTBYKEY(KEY_GUID('Key_CTC'), UPPER(REPLACE( CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)), char(0),''))) AS EncryptedLastName 	
	FROM person p 
	-- WHERE id = 1029
) p ON p.Id = ps.Id

/*
SELECT UPPER( DECRYPTBYKEY(MidName)) AS PatientName FROM person WHERE id = 1029

SELECT MidName AS PatientName FROM person WHERE id = 1029

SELECT ENCRYPTBYKEY(KEY_GUID('Key_CTC'),'Achieng') AS PatientName

SELECT FirstName, 
UPPER(REPLACE( CAST(DECRYPTBYKEY(MidName) AS VARCHAR(50)), char(0),''))
,
CAST(DECRYPTBYKEY(ENCRYPTBYKEY(KEY_GUID('key_CTC'),CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)))) AS VARCHAR(50)) AS EncryptedFirstName  FROM person WHERE  id = 1029



select  UPPER(REPLACE( CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)), char(0),'')) AS EncryptedMidName, UPPER(REPLACE( CAST(DECRYPTBYKEY(MidName) AS VARCHAR(50)), char(0),'')) AS EncryptedMidName, UPPER(REPLACE( CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)), char(0),'')) AS EncryptedMidName FrOM person WHERE  id = 1029
*/