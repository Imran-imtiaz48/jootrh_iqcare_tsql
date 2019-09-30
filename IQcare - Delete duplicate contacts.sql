select * from gcPatientView2 WHERE id = 10417


select * from IQTools_KeHMIS.dbo.tmp_PatientMaster WHERE PatientPK = 10416

select * from PersonContact WHERE PersonId = 60988

UPDATE pc1
SET pc1.DeleteFlag = 1
-- SELECT *
FROM
PersonContact pc1
INNER JOIN
 (
	select Id,PersonId,CreateDate, ROW_NUMBER() OVER(PARTItiON BY PersonId ORDER BY CReateDate DESC) as Rown from PersonContact c --WHERE c.PersonId = 25026 
) pc ON pc.id = pc1.Id
WHERE pc.Rown > 1 
 
