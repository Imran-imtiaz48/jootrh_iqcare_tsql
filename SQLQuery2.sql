SELECT a.PatientPK,
  a.PatientID,
  a.AgeARTStart,
  a.Gender,
  a.PatientName,
  a.StartARTDate,
  a.LastRegimenLine,
  d.Name as GLastRegimenLine,
  a.LastVisit
FROM tmp_ARTPatients a
  left JOIN (SELECT PatientPK,MAX(RegimenLine) AS RegimenLine,
            MAX(DispenseDate) AS DispenseDate
        FROM tmp_Pharmacy
        GROUP BY PatientPK) b ON a.PatientPK = b.PatientPK
  left join (SELECT ptn_pk,Max(DispensedByDate) as DispenceDate2,MAX(RegimenLine) AS RegimenLine2 
  from [IQCare_CPAD].[dbo].[ord_PatientPharmacyOrder]
    GROUP BY Ptn_pk
  ) c on a.PatientPK = c.Ptn_pk
  left join [IQCare_CPAD].[dbo].[LookupItem] d on c.RegimenLine2 = d.Id
--where a.LastRegimenLine  in ('second line') OR a.LastRegimenLine IS NULL
