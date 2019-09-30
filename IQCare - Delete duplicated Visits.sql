DELETE FROM PatientMasterVisit WHERE ID IN (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY v.PatientId, CAST(v.VisitDate AS DATE) ORDER BY s.Id DESC, v.VisitDate) as RowNumber,v.Id, v.PatientId, v.VisitDate FROM PatientMasterVisit v 
		INNER JOIN PatientScreening s ON s.PatientMasterVisitId = v.Id
		 WHERE [End] IS NULL --AND PatientId = 6860 
	) d WHERE RowNumber > 1
)


select * FROM gcPatientView WHERE id = 5