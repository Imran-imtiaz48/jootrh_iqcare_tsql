USE IQCare_CPAD
GO

DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate = '20190701'
set @endDate = '20190731'

;WITH all_Patients_cte AS (SELECT g.Id AS PatientID,
      g.PersonId,
      tp.ContactPhoneNumber,
      Upper(tp.ContactName) AS ContactName,
      g.EnrollmentNumber,
      Upper(tp.PatientName) AS PatientName,
      CASE WHEN g.Sex = 52 THEN 'F' ELSE 'M' END AS Sex,
      DateDiff(M, g.[EnrollmentDate ], @endDate) / 12 AS RegistrationAge,
      DateDiff(M, g.DateOfBirth, @endDate) / 12 AS currentAge,
      '' AS EnrolledAt,
      CAST(CASE WHEN TI.TransferInDate IS NOT NULL THEN TI.TransferInDate
        ELSE g.[EnrollmentDate ] END AS Date) AS EnrollmentDate,
      '' AS ARTStartDate,
      '' AS FirstVisitDate,
      '' AS LastVisitDate,
      P.NextAppointmentDate,
      CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason
      END PatientStatus,
      CAST(ce.ExitDate AS DATE) AS ExitDate,
      g.DateOfBirth,
      g.PatientType,
      tp.MaritalStatus,
      tp.EducationLevel,
      ce.ExitReason,
      tp.PhoneNumber
    FROM gcPatientView2 g
      LEFT JOIN (SELECT ce.PatientId,
        ce.ExitReason,
        ce.ExitDate,
        ce.TransferOutfacility,
        ce.CreatedBy
      FROM (SELECT ce.PatientId,
          l.Name AS ExitReason,
          ce.ExitDate,
          ce.TransferOutfacility,
          ce.CreatedBy,
          Row_Number() OVER (PARTITION BY ce.PatientId ORDER BY ce.CreateDate
          DESC) AS RowNum
        FROM patientcareending ce
          INNER JOIN LookupItem l ON l.Id = ce.ExitReason
          LEFT JOIN (SELECT X.PatientId,
            CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
          FROM PatientAppointment X
            INNER JOIN PatientMasterVisit v ON X.PatientMasterVisitId = v.Id
          WHERE v.VisitDate <= @endDate
          GROUP BY X.PatientId) pa ON pa.PatientId = ce.PatientId
        WHERE ce.DeleteFlag = 0 AND ((pa.NextAppointmentDate < @endDate AND
              l.Name <> 'Death' AND ce.ExitDate <= @endDate) OR
            (l.Name = 'Death' AND ce.ExitDate <= @endDate))) ce
      WHERE ce.RowNum = 1) ce ON g.Id = ce.PatientId
      LEFT JOIN (SELECT DISTINCT p.PatientPK,
        p.PatientName,
        p.ContactPhoneNumber,
        p.PhoneNumber,
        p.ContactName,
        p.MaritalStatus,
        p.EducationLevel,
        CONCAT(p.Landmark, '-', p.NearestHealthCentre) AS Address
      FROM IQTools_KeHMIS.dbo.tmp_PatientMaster p) tp ON tp.PatientPK = g.ptn_pk
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = g.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X
        INNER JOIN PatientMasterVisit v ON X.PatientMasterVisitId = v.Id
      WHERE v.VisitDate <= @endDate
      GROUP BY X.PatientId) P ON g.Id = P.PatientId),

  pending_vl_results_cte AS (SELECT *
    FROM (SELECT dbo.PatientLabTracker.patientId,
        dbo.PatientLabTracker.SampleDate AS VLDate,
        dbo.PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY dbo.PatientLabTracker.patientId ORDER BY
        dbo.PatientLabTracker.SampleDate DESC) AS RowNum
      FROM dbo.PatientLabTracker
      WHERE dbo.PatientLabTracker.SampleDate <= @endDate AND
        dbo.PatientLabTracker.Results = 'Pending' AND
        dbo.PatientLabTracker.LabTestId = 3) vlr),
  ti_cte AS (SELECT ti.PatientId,
      ti.TINumber
    FROM (SELECT Row_Number() OVER (PARTITION BY PatientIdentifier.PatientId
        ORDER BY PatientIdentifier.PatientId) AS rowNUm,
        PatientIdentifier.PatientId,
        PatientIdentifier.IdentifierValue AS TINumber
      FROM PatientIdentifier
      WHERE PatientIdentifier.IdentifierTypeId = 17) ti
    WHERE ti.rowNUm = 1),
  all_vl_sample_cte AS (SELECT DISTINCT t.patientId,
      CAST(t.SampleDate AS DATE) AS VlSampleDate,
      CASE WHEN tr.Undetectable = 1 OR t.ResultTexts LIKE '%< LDL%' THEN 0
        ELSE t.ResultValues END AS VLResults
    FROM dbo.PatientLabTracker t
      INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
    WHERE t.LabTestId = 3 AND t.SampleDate <= @endDate),
  last_vl_sample_cte AS (SELECT r.patientId,
      r.VlSampleDate,
      r.VLResults
    FROM (SELECT all_vl_sample_cte.patientId,
        all_vl_sample_cte.VlSampleDate,
        all_vl_sample_cte.VLResults,
        Row_Number() OVER (PARTITION BY all_vl_sample_cte.patientId ORDER BY
        all_vl_sample_cte.VlSampleDate DESC) AS RowNum
      FROM all_vl_sample_cte) r
    WHERE r.RowNum = 1)

SELECT DISTINCT
  a.EnrollmentNumber AS PatientId,
  ti.TINumber AS [JOOT TI Number],
  a.PatientName AS Name,
  a.Sex AS Sex,
  a.currentAge AS [Age],
  vls.VLResults,
  CAST(vls.VlSampleDate AS DATE) AS VLDate,
  CAST(a.NextAppointmentDate AS DATE) TCADate,
  CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS [Patient Type]
FROM all_Patients_cte a
  LEFT JOIN last_vl_sample_cte vls ON vls.patientId = a.PatientID
  LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
WHERE vls.VlSampleDate BETWEEN @startDate AND @endDate