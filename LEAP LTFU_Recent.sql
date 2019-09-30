Declare @fromdate as datetime='2019-06-01', @todate as datetime='2019-06-06'


SELECT distinct a.PatientPK,a.Patientid,
    a.Gender, 
    a.AgeLastVisit,
    dbo.fn_GetAgeGroup(Round(a.AgeARTStart, 0), 'DATIM') ageGroup,
    RegistrationDate,
    StartARTDate,
    LastARTDate, 
	e.ExpectedReturn,
	DATEDIFF(DAY, e.ExpectedReturn, @ToDate) AS DaysLost
	 FROM tmp_ARTPatients a INNER JOIN (SELECT * FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK ORDER
		BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,  tmp_Pharmacy.PatientPK, tmp_Pharmacy.DispenseDate,
		tmp_Pharmacy.Duration, tmp_Pharmacy.ExpectedReturn FROM tmp_Pharmacy
	WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
		tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
	WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
	LEFT JOIN (SELECT * FROM tmp_LastStatus c WHERE c.ExitDate < @fromdate) c ON c.PatientPK = a.PatientPK
	INNER JOIN (
		SELECT p.ptn_pk AS PatientPK, CAST(MAX(e.AppointmentDate) AS DATE) as ExpectedReturn FROM IQCare_CPAD.dbo.PatientAppointment e 
		INNER JOIN IQCare_CPAD.dbo.PatientMasterVisit v ON e.PatientMasterVisitId = v.Id
		INNER JOIN IQCare_CPAD.dbo.Patient p ON p.id = v.PatientId
		 WHERE v.VisitDate <=@todate AND e.AppointmentDate IS NOT NULL GROUP BY p.ptn_pk
	) e ON e.PatientPK = a.PatientPK
WHERE dateadd(dd, 31 ,e.ExpectedReturn) between CAST(@fromDate AS datetime) and CAST(@toDate AS datetime)
		AND a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
	  datetime) AND a.StartARTDate <= CAST(@toDate AS datetime) AND  (c.ExitReason IS NULL or c.exitDate >CAST(@todate AS datetime)) 
	   AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL)