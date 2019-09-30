WITH current_in_care_cte AS (SELECT A.ptn_pk,
      A.PersonId,
      c.IdentifierValue AS PatientID,
      c.IdentifierOld AS PatientIDOld,
      DateDiff(yy, A.DateOfBirth, A.RegistrationDate) AS RegistrationAge,
      DateDiff(yy, A.DateOfBirth, GetDate()) AS currentAge,
      A.RegistrationDate,
      Z.VisitDate,
      P.NextAppointmentDate
    FROM IQCare_CPAD.dbo.Patient A
      INNER JOIN (
	  SELECT IQCare_CPAD.dbo.PatientMasterVisit.PatientId,
        Max(IQCare_CPAD.dbo.PatientMasterVisit.VisitDate
		
		) AS VisitDate
      FROM IQCare_CPAD.dbo.PatientMasterVisit
      GROUP BY IQCare_CPAD.dbo.PatientMasterVisit.PatientId) Z
        ON A.Id = Z.PatientId
      LEFT OUTER JOIN (SELECT M.PatientId,
        M.Id,
        M.DispensedByDate AS DispensedDate,
        M.Regimen
      FROM (SELECT PatientTreatmentTrackerView.Id,
          PatientTreatmentTrackerView.PatientId,
          PatientTreatmentTrackerView.DispensedByDate,
          PatientTreatmentTrackerView.Regimen,
          Row_Number() OVER (PARTITION BY PatientTreatmentTrackerView.PatientId
          ORDER BY PatientTreatmentTrackerView.DispensedByDate DESC) RowNum
        FROM PatientTreatmentTrackerView
        WHERE PatientTreatmentTrackerView.DispensedByDate IS NOT NULL AND
          PatientTreatmentTrackerView.Regimen <> 'unknown') AS M
      WHERE M.RowNum = 1) AS T ON T.PatientId = A.Id
      INNER JOIN IQCare_CPAD.dbo.LookupItem f ON A.PatientType = f.Id
      INNER JOIN (SELECT *
      FROM (SELECT *,
          Row_Number() OVER (PARTITION BY PatientIdentifier.PatientId ORDER BY
          PatientIdentifier.PatientId DESC) AS rowNum
        FROM PatientIdentifier) pid
      WHERE pid.rowNum = 1) c ON A.Id = c.PatientId
      INNER JOIN IQCare_CPAD.dbo.Person b ON A.PersonId = b.Id
      INNER JOIN IQCare_CPAD.dbo.LookupItem m ON b.Sex = m.Id
      LEFT JOIN (SELECT Y.ptn_pk AS PatientPK,
        Max(X.AppointmentDate) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X
        INNER JOIN IQCare_CPAD.dbo.Patient Y ON X.PatientId = Y.Id
      GROUP BY Y.ptn_pk) P ON A.ptn_pk = P.PatientPK
    WHERE P.NextAppointmentDate IS NOT NULL AND A.DeleteFlag = 0 AND
      A.Id NOT IN (SELECT IQCare_CPAD.dbo.PatientCareending.PatientId
      FROM IQCare_CPAD.dbo.PatientCareending) AND A.Id NOT IN (SELECT Patient.Id
        AS PatientId
      FROM dtl_PatientCareEnded INNER JOIN Patient
          ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk))
SELECT current_in_care_cte.PatientID,
  p.PatientName,
  p.Gender,
  p.DOB,
  p.AgeCurrent,
  p.AgeLastVisit,
  p.AgeEnrollment,
  vl.LastVL,
  vl.LastVLDate,
--  current_in_care_cte.currentAge,
  current_in_care_cte.VisitDate,
  current_in_care_cte.NextAppointmentDate
FROM current_in_care_cte
  LEFT JOIN [IQTools_KeHMIS].dbo.IQC_LastVL vl ON current_in_care_cte.ptn_pk = vl.PatientPK
  INNER JOIN [IQTools_KeHMIS].dbo.tmp_PatientMaster p ON p.PatientPK = current_in_care_cte.ptn_pk
  WHERE (CASE WHEN ISNUMERIC(vl.LastVL) = 1 THEN CAST(vl.LastVL AS float) ELSE 0 END) > 1000
  -- vl.LastVL IS NULL

--  SELECT ISNUMERIC('xxx')