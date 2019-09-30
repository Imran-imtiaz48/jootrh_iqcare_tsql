
DELETE FROM PatientIptOutcome wHERE id IN (
	SELECT ID FROM (
		select id, PatientId ,ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate) as rown from PatientIptOutcome WHERE IptEvent = 525 --completed
	) io WHERE io.rown > 1
)


delete from PatientIptWorkup WHERE id IN (
	SELECT id FROM PatientIptWorkup WHERE DATEDIFF(M, IptStartDate, '2019-04-19') < 6 AND IptStartDate = 1
 ) 


 select * from PatientIptWorkup WHERE PatientId =11868

 select * from PatientIptOutcome WHERE PatientId =11868
