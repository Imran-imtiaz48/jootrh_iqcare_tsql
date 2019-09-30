SELECT pt.DateOfBirth, ps.DateOfBirth
FROM patient pt 
INNER JOIN person ps
ON pt.PersonId = ps.Id
WHERE 
ps.DateOfBirth <> pt.DateOfBirth

UPDATE pt
SET pt.DateOfBirth = ps.DateOfBirth
FROM patient pt 
INNER JOIN person ps
ON pt.PersonId = ps.Id
WHERE 
ps.DateOfBirth <> pt.DateOfBirth

UPDATE pt
SET pt.DOB = ps.DateOfBirth
FROM mst_patient pt 
INNER JOIN patient pst ON pst.ptn_pk = pt.Ptn_Pk
INNER JOIN person ps ON ps.Id = pst.PersonId
WHERE ps.DateOfBirth <> pt.DOB

SELECT pt.DateOfBirth, ps.DateOfBirth
FROM patient pt 
INNER JOIN person ps
ON pt.PersonId = ps.Id
WHERE 
ps.DateOfBirth <> pt.DateOfBirth
