SELECT tmp_PatientMaster.PatientID,
  tmp_PatientMaster.AgeCurrent,
  tmp_PatientMaster.Gender,
  tmp_Pharmacy.Drug,
  tmp_PatientMaster.LastVisit
FROM tmp_PatientMaster
  INNER JOIN tmp_Pharmacy ON tmp_PatientMaster.PatientPK =
    tmp_Pharmacy.PatientPK