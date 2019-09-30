--select * from PatientLabTracker WHERE patientId = 4985

;WITH providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 --or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
)
--select * from providers_cte
--return
UPDATE a
SET a.ServiceAreaId = 20
--SELECT v.PatientId,v.VisitDate, v.CreatedBy,p.ProviderName, a.ServiceAreaId 
FROM PatientAppointment a 
INNER JOIN PatientMasterVisit v ON a.PatientMasterVisitId = v.Id
INNER JOIN PatientEncounter e ON v.id = e.PatientMasterVisitId
INNER JOIN providers_cte p ON e.CreatedBy = p.UserID
WHERE 
--v.PatientId = 6869

--DATEDIFF(MONTH,v.VisitDate,GETDATE()) < =6
--AND v.CreateDate < '2019-05-27'
--AND (p.ProviderName LIKE '%Susan%' OR P.ProviderName LIKE '%Diana%' OR P.ProviderName LIKE '%Brenda%' OR P.ProviderName LIKE '%Nancy%') AND a.ServiceAreaId<> 19--MCH
--AND (p.ProviderName LIKE '%Mate%' OR P.ProviderName LIKE '%Collins%') AND a.ServiceAreaId <> 20--TB
--AND (p.ProviderName LIKE '%Calvin%' OR P.ProviderName LIKE '%Austn%') AND a.ServiceAreaId<>2404 --MAT
v.VisitDate BETWEEN '2017-10-01' AND '2018-09-30'
--AND (p.ProviderName LIKE '%Sharon%' OR P.ProviderName LIKE '%Omunyolo%') AND a.ServiceAreaId<> 19--MCH
AND (p.ProviderName LIKE '%Vivian%' OR P.ProviderName LIKE '%Lameck Nelson%') AND a.ServiceAreaId <> 20--TB

-- select * from LookupItem WHERE id = 19


