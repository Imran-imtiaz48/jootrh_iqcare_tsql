Declare @FromDate as datetime='2019-06-21', @ToDate as datetime='2019-06-27'


SELECT a.*
FROM (SELECT DISTINCT a.PatientPK,
    a.PatientID,
    a.Gender,
    a.AgeLastVisit,
    dbo.fn_GetAgeGroup(Round(a.AgeARTStart, 0), 'DATIM') ageGroup,
    CAST(a.RegistrationDate AS date) RegistrationDate,
    CAST(a.StartARTDate AS date) StartARTDate,
    CAST(a.LastARTDate AS date) LastARTDate
  FROM tmp_ARTPatients a
    LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
  WHERE (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
    (a.PatientType <> 'Transfer-In' OR a.PatientType IS NULL) AND
    (a.PatientSource <> 'Transfer In' OR a.PatientSource IS NULL) AND
    a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
    datetime) AND a.RegistrationDate <= CAST(@todate AS datetime) AND
    (a.PreviousARTStartDate IS NULL OR a.PreviousARTStartDate BETWEEN
      CAST(@fromdate AS datetime) AND CAST(@todate AS datetime))) a


	   