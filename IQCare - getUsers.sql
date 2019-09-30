select * from mst_User order by CreateDate ASC

select DISTINCT  CONCAT(u.UserFirstName, ' ', u.UserLastName)  from PatientMasterVisit v
INNER JOIN mst_User u ON u.UserID = v.CreatedBy
 WHERE v.CreateDate BETWEEN '2019-01-01' AND '2019-02-28'



