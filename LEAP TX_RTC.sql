Declare @fromdate as datetime='2019-06-21', @todate as datetime='2019-06-27'


SELECT DISTINCT a.PatientPk,a.PatientID, a.Gender, DOB, a.LastARTDate, p.LastLTFUDate PreviousExpected_Date, DATEDIFF(DAY, p.LastLTFUDate, @ToDate) AS DaysPrevLost, e.CareModel
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
--AND e.CareModel = 'ST' OR (e.CareModel = 'DC' AND DATEDIFF(DAY, p.LastLTFUDate, @ToDate) > 90)
