SELECT tmp_PatientMaster.PatientID,
  tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  tmp_ARTPatients.LastVisit,
  tmp_ARTPatients.StartARTDate,
  tmp_ARTPatients.AgeLastVisit,
  DateDiff(m, IQC_LastVL.LastVLDate, '2018-03-01') AS 'Months Since Last VL',
  CAST(IQC_LastVL.LastVLResult AS float) AS LastVL
FROM tmp_PatientMaster
  LEFT JOIN (SELECT *
  FROM (SELECT CAST(Row_Number() OVER (PARTITION BY p.PatientPK ORDER BY
      p.OrderedbyDate DESC) AS Varchar) AS RowID,
      p.PatientPK,
      CAST(Floor(p.TestResult) AS int) LastVLResult,
      CASE WHEN p.TestName = 'Viral Load' THEN p.TestResult
        WHEN p.TestName = 'ViralLoad Undetectable' THEN 'Undetectable' ELSE NULL
      END AS LastVL,
      p.OrderedbyDate LastVLDate
    FROM tmp_Labs p
    WHERE p.OrderedbyDate <= '2018-03-01' AND p.TestName LIKE '%Viral%') AS LastVLTbl
  WHERE LastVLTbl.RowID = 1) AS IQC_LastVL ON tmp_PatientMaster.PatientPK =
    IQC_LastVL.PatientPK
  LEFT JOIN tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
(
	(DateDiff(m, IQC_LastVL.LastVLDate, '2018-03-01') = 12) OR
	(IQC_LastVL.LastVLResult > 1000 AND DateDiff(m, IQC_LastVL.LastVLDate, '2018-03-01') = 3) OR
    (DateDiff(m, tmp_ARTPatients.StartARTDate, '2018-03-01') = 6)
 )
AND
 tmp_PatientMaster.PatientPk = 2734