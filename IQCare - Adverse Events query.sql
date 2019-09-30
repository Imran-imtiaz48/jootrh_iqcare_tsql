SELECT DISTINCT mst_Patient.PatientEnrollmentID AS PatientId, CAST(v.VisitDate AS DATE) AS VisitDate, av.EventName, av.EventCause, l2.DisplayName AS Severity, av.Action, l1.DisplayName AS Outcome, o.OutcomeDate
FROM            AdverseEvent AS av INNER JOIN
                         Patient ON av.PatientId = Patient.Id INNER JOIN
                         mst_Patient ON Patient.ptn_pk = mst_Patient.Ptn_Pk INNER JOIN
                         PatientMasterVisit AS v ON av.PatientMasterVisitId = v.Id INNER JOIN
                         LookupItem AS l2 ON av.Severity = l2.Id LEFT OUTER JOIN
                         PatientAdverseEventOutcome AS o ON o.AdverseEventId = av.Id LEFT OUTER JOIN
                         LookupItem AS l1 ON o.OutComeId = l1.Id
ORDER BY PatientId, VisitDate DESC