SELECT pt.EnrollmentNumber AS PatientId,
  pm.Gender,
  pm.PatientName,
  ART.StartARTDate AS ARTStartDate,
  pm.AgeCurrent,
  pm.AgeEnrollment,
  pm.AgeLastVisit,
  pm.DOB,
  pm.PatientSource,
  c.ExitDate,
  c.TransferOutfacility,
  c.DateOfDeath,
  c.CareEndingNotes,
  l.DisplayName AS ExitReason,
  lv.LastVisitDate,
  ART.LastARTDate,
  app.NextAppointmentDate
FROM PatientCareending AS c
  INNER JOIN LookupItem AS l ON c.ExitReason = l.Id
  INNER JOIN Patient AS p ON c.PatientId = p.Id
  INNER JOIN IQTools_KeHMIS.dbo.tmp_PatientMaster AS pm ON p.ptn_pk =
    pm.PatientPK
  INNER JOIN gcPatientView AS pt ON c.PatientId = pt.Id
  INNER JOIN IQTools_KeHMIS.dbo.tmp_ARTPatients AS ART ON ART.PatientPK =
    pm.PatientPK
LEFT JOIN (SELECT Y.ptn_pk AS PatientPK,
    Max(X.AppointmentDate) AS NextAppointmentDate
  FROM IQCare_CPAD.dbo.PatientAppointment X
    INNER JOIN IQCare_CPAD.dbo.Patient Y ON X.PatientId = Y.Id
  GROUP BY Y.ptn_pk) App ON App.PatientPK = p.ptn_pk
LEFT JOIN (SELECT Y.ptn_pk AS PatientPK,
    Max(X.VisitDate) AS LastVisitDate
  FROM IQCare_CPAD.dbo.PatientMasterVisit X
    INNER JOIN IQCare_CPAD.dbo.Patient Y ON X.PatientId = Y.Id WHERE X.Active = 1
  GROUP BY Y.ptn_pk) lv ON lv.PatientPK = p.ptn_pk

WHERE c.ExitDate BETWEEN '2018-01-01' AND '2018-03-31' AND c.DeleteFlag = 0