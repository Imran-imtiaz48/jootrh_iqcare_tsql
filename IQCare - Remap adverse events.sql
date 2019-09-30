-- EventName = EventCause
-- EventCause = "Get event cause(medicine causing) from history"
-- AdverseEventId = EventName (As long as EventName >0)
--Action=Other


DELETE FROM AdverseEvent WHERE EventName = 0 ANd AdverseEventId = 0
UPDATE ae SET ae.EventName = a.EventName, ae.EventCause = a.EventCause, ae.AdverseEventId = a.AdverseEventId
--SELECT* 
FROM AdverseEvent ae INNER JOIN (
	SELECT id,PatientId, --EventCause,
	COALESCE
	(
	 (SELECT TOP 1 EventCause FROM AdverseEvent ae WHERE ae.PatientId=a.PatientId AND ISNUMERIC(EventCause) = 0 AND EventCause NOT IN (SELECT [Name] FROM LookupItem) AND LEN(EventCause) < 18 ORDER BY CreateDate DESC),
	 REPLACE(REPLACE(REPLACE(REPLACE(REPLACE((SELECT TOP 1 regimenType FROM RegimenMapView r WHERE a.Patientid = r.PatientId AND r.VisitDate <= a.CreateDate ORDER BY VisitDate DESC),'/',''),'TDF',''),'3TC',''),'AZT',''),'ABC','')
	)
	 AS EventCause,EventName AS AdverseEventId, (SELECT TOP 1 Name FROM LookupItem l WHERE l.id = a.EventName) AS EventName, 
	 COALESCE((SELECT TOP 1 Action FROM AdverseEvent ae WHERE ae.PatientId=a.PatientId AND ae.Action NOT IN (select ItemName from LookupItemView WHERE MasterId = 28 ) ORDER BY a.CreateDate DESC), 'Other') AS Action 
	 FROM AdverseEvent a
	WHERE
	ISNUMERIC(EventName) = 1
	AND EventName > 0
--	AND       (a.PatientId = 34603)
) a ON a.Id = ae.Id

return

SELECT        a.Id, a.PatientId, a.PatientMasterVisitId, a.EventName, a.EventCause, a.Severity, a.Action, a.DeleteFlag, a.CreateBy, a.CreateDate, a.AuditData, a.AdverseEventId, m.VisitDate
FROM            AdverseEvent AS a INNER JOIN
                         PatientMasterVisit AS m ON a.PatientMasterVisitId = m.Id
WHERE 
ISNUMERIC(EventName) = 1 AND       
(a.PatientId = 34603)

--SELECT * FROM LookupItem WHERE id = 105
select * from LookupItemView WHERE MasterId = 28

SELECT REPLACE('TDF/3TC','TDF','') 

--select distinct PatientId from AdverseEvent
select distinct EventCause from AdverseEvent
select * from RegimenMapView WHERE PatientId = 5179

--select * from gcPatientView where EnrollmentNumber like '%24354%'
--select * from gcPatientView where EnrollmentNumber like '%06541%'

--select * from LookupItemView WHERE itemId = 1463


--select* from mst_User where UserID =83

EXEC sp_getPatientEncounterAdverseEvents 34550, 9378