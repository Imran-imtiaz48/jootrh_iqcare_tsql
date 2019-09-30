SELECT QTZ_Report_Master.*,
  CASE WHEN ViralLoadEligibility.PatientID IS NOT NULL THEN 'YES'
  END AS [VL Eligible]
FROM (SELECT tmp_PatientMaster.PatientID,
    tmp_PatientMaster.Gender,
    tmp_PatientMaster.RegistrationDate,
    tmp_PatientMaster.LastVisit,
    tmp_PatientMaster.StatusAtCCC,
    IQC_FirstVL.FirstVL,
    IQC_FirstVL.FirstVLDate,
    IQC_LastVL.LastVL,
    IQC_LastVL.LastVLDate,
    DateDiff(yy, tmp_PatientMaster.DOB, '2017-11-30') AS age_at_visit
  FROM tmp_PatientMaster
    LEFT JOIN IQC_FirstVL ON tmp_PatientMaster.PatientPK = IQC_FirstVL.PatientPK
    INNER JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  WHERE DateDiff(yy, tmp_PatientMaster.DOB, '2017-11-30') >= 10 AND
    DateDiff(yy, tmp_PatientMaster.DOB, '2017-11-30') <= 24) QTZ_Report_Master
  LEFT JOIN (SELECT InitOnArtPastSixMonths.PatientID
  FROM tmp_ARTPatients InitOnArtPastSixMonths
  WHERE DateDiff(m, InitOnArtPastSixMonths.StartARTDate, '2017-11-30') <= 6
  UNION
  SELECT tmp_PatientMaster.PatientID
  FROM IQC_LastVL
    INNER JOIN tmp_PatientMaster ON tmp_PatientMaster.PatientPK =
      IQC_LastVL.PatientPK
  WHERE DateDiff(m, IQC_LastVL.LastVLDate, '2017-11-30') = 12
  UNION
  SELECT tmp_PatientMaster.PatientID
  FROM IQC_LastVL
    INNER JOIN tmp_PatientMaster ON IQC_LastVL.PatientPK =
      tmp_PatientMaster.PatientPK
  WHERE DateDiff(m, IQC_LastVL.LastVLDate, '2017-11-30') <= 3 AND
    IQC_LastVL.LastVLResult > 1000) ViralLoadEligibility
    ON QTZ_Report_Master.PatientID = ViralLoadEligibility.PatientID