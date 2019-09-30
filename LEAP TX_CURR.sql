Declare @FromDate as datetime='2019-06-07', @ToDate as datetime='2019-06-13'

SELECT  distinct a.PatientPK, a.patientid,
    a.Gender,
    a.ageGroup,
    a.LastARTDate,
	a.ExpectedReturn,
	a.ExitDate,
	a.ExitReason
FROM (SELECT DISTINCT a.FacilityName,
    a.SatelliteName,
    a.PatientPK,a.PatientID,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'DATIM') ageGroup,
    CAST(a.LastARTDate AS date) LastARTDate,
    e.ExpectedReturn,
	c.ExitReason,c.ExitDate,
    CASE
      WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) > 90 AND
      c.ExitReason IS NULL THEN 'Lost'
      WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) BETWEEN 14
      AND 90 AND c.ExitReason IS NULL THEN 'Defaulted'
      WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) < 14 AND
      c.ExitReason IS NULL THEN 'Active' ELSE c.ExitReason END AS ARTStatus
  FROM tmp_ARTPatients a
    INNER JOIN (
		SELECT *
		FROM (
				SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
					ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
					tmp_Pharmacy.PatientPK,
					tmp_Pharmacy.DispenseDate,
					tmp_Pharmacy.Duration,
					tmp_Pharmacy.ExpectedReturn
				  FROM tmp_Pharmacy
				  WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
					tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')
			) AS RP
		WHERE RP.RowID = 1
	) p ON a.PatientPK = p.PatientPK
    LEFT JOIN (SELECT * FROM tmp_LastStatus c WHERE c.ExitDate < @fromdate) c ON a.PatientPK = c.PatientPK
	INNER JOIN (
		SELECT p.ptn_pk AS PatientPK, CAST(MAX(e.AppointmentDate) AS DATE) as ExpectedReturn FROM IQCare_CPAD.dbo.PatientAppointment e 
		INNER JOIN IQCare_CPAD.dbo.PatientMasterVisit v ON e.PatientMasterVisitId = v.Id
		INNER JOIN IQCare_CPAD.dbo.Patient p ON p.id = v.PatientId
		 WHERE v.VisitDate <=@todate AND e.AppointmentDate IS NOT NULL GROUP BY p.ptn_pk
	) e ON e.PatientPK = a.PatientPK
  WHERE ((
			CASE
			  WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) >
			  90 THEN 'Lost'
			  WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) BETWEEN 31
			  AND 90 THEN 'ULTFU'
			  WHEN DateDiff(dd, e.ExpectedReturn, CAST(@todate AS datetime)) <=
			  30 THEN 'Defaulted' ELSE c.ExitReason 
			END IN ('Active')
		) OR
		(
			a.RegistrationDate IS NOT NULL AND 
			a.RegistrationDate <= CAST(@toDate AS datetime) AND 
			a.StartARTDate <= CAST(@toDate AS datetime) AND
			DateAdd(day, 30, e.ExpectedReturn) >= CAST(@toDate AS datetime) AND
			(c.ExitReason IS NULL OR c.ExitReason <> 'Death') AND 
			(a.PatientType <> 'Transit' OR a.PatientType IS NULL)
		)) --AND 	a.PatientPk = 23250


  GROUP BY a.FacilityName,
    a.SatelliteName,
    a.PatientPK,a.PatientID,
    a.Gender,
    e.ExpectedReturn,
    a.DOB,
    a.LastARTDate,
	c.ExitDate,
    c.ExitReason) a
	order by a.expectedReturn

--	select * from tmp_LastStatus WHERE PatientPK =23250

