
SELECT 
	p.EnrollmentNumber,CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, p.DateOfBirth, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge,t.VisitDate,t.CurrentlyOnIPT,t.EverBeenOnIpt,p.PatientStatus,p.ExitDate 
--	p.EnrollmentNumber,CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, p.DateOfBirth, DATEDIFF(YY, DateOfBirth, GETDATE()) AS currentAge,t.lastScreeningDate,t.ScreeningResult,p.PatientStatus,p.ExitDate 
	FROM  (
		SELECT PatientId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY EverBeenOnIpt Desc, OnIpt, CreateDate Desc) as RowNum, CASE WHEN OnIpt IS NULL THEN 'Unknown' WHEN OnIPt = 1 THEN 'Y' ELSE 'N' END as CurrentlyOnIPT, CASE WHEN EverBeenOnIpt IS NULL THEN NULL WHEN EverBeenOnIpt=1 THEN 'Y' ELSE 'N' END AS EverBeenOnIpt, CreateDate as VisitDate FROM PatientICF
		 
/*		SELECT ROW_NUMBER() OVER(PARTITION BY t.PatientId ORDER BY v.CreateDate Desc) as RowNum, 
		CONCAT(l.Name, ' - ', l.DisplayName) as ScreeningResult,ScreeningValueId,
		t.PatientId,PatientMasterVisitId,CAST(v.CreateDate AS Date) as lastScreeningDate
		from PatientScreening t
		inner join LookupItem l on t.ScreeningValueId = l.Id 
		inner join PatientMasterVisit v ON v.Id = t.PatientMasterVisitId
		WHERE ScreeningTypeId = 4 AND ScreeningValueId = 30*/
) t 
RIGHT JOIN gcPatientView p ON p.Id = t.PatientId AND RowNum = 1
ORDER BY VisitDate DESC
--WHERE RowNum = 1

--select * from PatientICF

