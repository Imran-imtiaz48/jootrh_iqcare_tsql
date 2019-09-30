
SELECT e.Id, u.UserID, CONCAT(u.UserFirstName, ' ', u.userLastName) as Name, CAST(e.EncounterStartTime AS DATE) as EncounterDate, l.Name as FinalResult FROM HtsEncounter h 
INNER JOIN mst_User u ON u.UserID = h.ProviderId
INNER JOIN PatientEncounter e ON e.Id = h.PatientEncounterID
INNER JOIN HtsEncounterResult r ON r.HtsEncounterId = h.Id
INNER JOIN LookupItem l ON l.Id = r.FinalResult
-- WHERE u.UserID  = 130
WHERE EncounterStartTime < = '2019-01-17'
ORDER BY encounterdate DESC

-- select * from LookupItem WHERE id = 1444

-- select * from HtsEncounterResult

