Declare @FromDate as datetime='2019-06-07', @ToDate as datetime='2019-06-23'

SELECT FORMAT(CAST(@FromDate AS DATE), 'dd MMM, yyyy', 'en-GB') AS FromDate, FORMAT(CAST(@ToDate AS Date), 'dd MMM, yyyy','en-GB') AS ToDate, 
Count(DISTINCT a.PatientPK) Tx_New,
(SELECT  Count(DISTINCT a.PatientPK) Tx_CURR
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
)Tx_CURR,
(SELECT count(DISTINCT a.PatientID)LTFU_Recent 
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
	   AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL))LTFU_Recent,
(SELECT count(DISTINCT a.PatientPk)Tx_RTC
FROM tmp_ARTPatients a 
INNER JOIN (
	SELECT * FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK ORDER BY tmp_Pharmacy.DispenseDate asc) AS Varchar) AS RowID,
	tmp_Pharmacy.PatientPK,tmp_Pharmacy.DispenseDate, tmp_Pharmacy.Duration,tmp_Pharmacy.ExpectedReturn,ltfu.ExpectedReturn LastLTFUDate
	FROM tmp_Pharmacy left join (
			Select Distinct p.PatientPK, a.PatientID, Upper(a.PatientName) [Patient Name], a.Gender, a.StartARTDate, a.PreviousARTStartDate, 
			dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12 AgeAtVisit, Cast(Max(p.DispenseDate) As Date) DispensedDate, 
			a.LastRegimen [Current Regimen], DBO.fn_DateDiff('dd', Max(p.DispenseDate), Max(p.ExpectedReturn)) DurationOfDrugs, 
			Cast(Max(p.ExpectedReturn) As Date) ExpectedReturn From tmp_ARTPatients a 
			Inner Join (
				Select * From (
					Select Cast(Row_Number() Over (Partition By tmp_Pharmacy.PatientPK Order By tmp_Pharmacy.DispenseDate Desc) As Varchar) As RowID, 
					tmp_Pharmacy.PatientPK, tmp_Pharmacy.DispenseDate, tmp_Pharmacy.Duration, tmp_Pharmacy.ExpectedReturn From tmp_Pharmacy 
					Where tmp_Pharmacy.DispenseDate <= Cast(@fromDate As DateTime) And tmp_Pharmacy.TreatmentType In ('ART', 'PMTCT')
				) As RP Where RP.RowID = 1

			) p On a.PatientPK = p.PatientPK 
			Left Join (	SELECT * FROM tmp_LastStatus c WHERE c.ExitDate < @fromdate) c On c.PatientPK = a.PatientPK Where a.RegistrationDate Is Not Null And 
				a.RegistrationDate <= Cast(@fromDate As datetime) And a.StartARTDate <= Cast(@fromDate As datetime) And DateDiff(DAY, p.ExpectedReturn, Cast(@fromdate As datetime)) >30  And (c.ExitReason Is Null Or c.ExitReason <> 'Death') And 
			(a.PatientType <> 'Transit' Or a.PatientType Is Null) Group By p.PatientPK, a.PatientID, a.Gender, a.StartARTDate, a.PreviousARTStartDate, a.LastRegimen, a.DOB, a.PatientName
		) ltfu on ltfu.PatientPK=tmp_Pharmacy.Patientpk
		WHERE tmp_Pharmacy.DispenseDate between cast(ltfu.ExpectedReturn as datetime) and  CAST(@ToDate AS DateTime) AND
			tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP WHERE RP.RowID = 1		
) p ON a.PatientPK = p.PatientPK
LEFT JOIN (SELECT * FROM tmp_LastStatus c WHERE c.ExitDate < @fromdate) c ON c.PatientPK = a.PatientPK
INNER JOIN (
		SELECT * FROM (
			SELECT p.ptn_pk AS PatientPK, CAST(e.AppointmentDate AS DATE) as ExpectedReturn, CASE WHEN e.DifferentiatedCareId IN (1615,236,254) THEN 'DC' ELSE 'ST' END AS CareModel, ROW_NUMBER() OVER(PARTITION BY p.ptn_pk ORDER BY e.AppointmentDate DESC) AS rown FROM IQCare_CPAD.dbo.PatientAppointment e 
			INNER JOIN IQCare_CPAD.dbo.PatientMasterVisit v ON e.PatientMasterVisitId = v.Id
			INNER JOIN IQCare_CPAD.dbo.Patient p ON p.id = v.PatientId
			 WHERE v.VisitDate <=@todate AND e.AppointmentDate IS NOT NULL-- GROUP BY p.ptn_pk
		) e1 WHERE e1.rown = 1 
	) e ON e.PatientPK = a.PatientPK
WHERE  a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
datetime) AND a.StartARTDate <= CAST(@toDate AS datetime) AND
p.DispenseDate between  CAST(@fromDate AS datetime) and CAST(@todate AS datetime) 
AND e.CareModel = 'ST' OR (e.CareModel = 'DC' AND DATEDIFF(DAY, p.LastLTFUDate, @ToDate) > 90)) TX_RTC,
		(SELECT Count(DISTINCT a.PatientPK) HTS_TST FROM dbo.tmp_HTS_LAB_register a
		  INNER JOIN tmp_PatientMaster b ON b.PatientPK = a.PatientPK
			WHERE a.VisitDate BETWEEN CAST(@FromDate AS datetime) AND CAST(@ToDate AS datetime) )HTS_TST,
		(SELECT Count(DISTINCT a.PatientPK) HTS_POS_Overall FROM dbo.tmp_HTS_LAB_register a INNER JOIN tmp_PatientMaster b ON b.PatientPK = a.PatientPK
		WHERE a.VisitDate BETWEEN CAST(@FromDate AS datetime) AND CAST(@ToDate
  AS datetime) AND a.finalResultHTS = 'Positive')HTS_POS_Overall,
  (select COUNT(*) AS Death from tmp_LastStatus a 
INNER JOIN (SELECT * FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK ORDER
		BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,  tmp_Pharmacy.PatientPK, tmp_Pharmacy.DispenseDate,
		tmp_Pharmacy.Duration, tmp_Pharmacy.ExpectedReturn FROM tmp_Pharmacy
	WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
		tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
	WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
 WHERE ExitDate BETWEEN @fromdate AND @todate AND ExitReason ='Death') AS Death,

 (select COUNT(*) AS TrabsferOut from tmp_LastStatus a 
INNER JOIN (SELECT * FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK ORDER
		BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,  tmp_Pharmacy.PatientPK, tmp_Pharmacy.DispenseDate,
		tmp_Pharmacy.Duration, tmp_Pharmacy.ExpectedReturn FROM tmp_Pharmacy
	WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
		tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
	WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
 WHERE p.ExpectedReturn BETWEEN @fromdate AND @todate AND ExitReason ='Transfer') AS TransferOut
FROM (SELECT DISTINCT a.FacilityName,
    a.PatientPK,
    a.Gender,
    a.AgeLastVisit,
    dbo.fn_GetAgeGroup(Round(a.AgeARTStart, 0), 'DATIM') ageGroup,
    CAST(a.RegistrationDate AS date) RegistrationDate,
    CAST(a.StartARTDate AS date) StartARTDate,
    CAST(a.LastARTDate AS date) LastARTDate
  FROM tmp_ARTPatients a
    LEFT JOIN (SELECT * FROM tmp_LastStatus c WHERE c.ExitDate < @fromdate) c ON a.PatientPK = c.PatientPK
  WHERE a.StartARTDate BETWEEN CAST(@FromDate AS datetime) AND CAST(@ToDate AS
    datetime) AND a.RegistrationDate <= CAST(@ToDate AS datetime) AND
    (a.PreviousARTStartDate IS NULL OR a.PreviousARTStartDate BETWEEN
      CAST(@FromDate AS datetime) AND CAST(@ToDate AS datetime)) AND
    (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
    (a.PatientType <> 'Transfer-In' OR a.PatientType IS NULL) AND
    (a.PatientSource <> 'Transfer In' OR a.PatientSource IS NULL)) a 