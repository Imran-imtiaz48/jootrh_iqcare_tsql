use [IQTools_KeHMIS]
GO

	/*
	Initiated On ART for the past 6 months
	*/
SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  tmp_ARTPatients.LastVisit,
  tmp_ARTPatients.StartARTDate,
  tmp_ARTPatients.AgeLastVisit,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  tmp_PatientMaster.PatientID
FROM tmp_PatientMaster
  INNER JOIN tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
	DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') <= 6 AND DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') >= 0

  /*
  Routine Viral Load
  */
SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') as 'Months Since Last VL',
  CAST(IQC_LastVL.LastVLResult AS float) as LastVL
FROM tmp_PatientMaster
  INNER JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  WHERE 
  DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') = 12


	/*
	High VL recorded 3 months ago
	*/
SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') as 'Months Since Last VL',
  CAST(IQC_LastVL.LastVL AS float) as LastVL
FROM tmp_PatientMaster
  INNER JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  WHERE DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') <= 3 
  AND IQC_LastVL.LastVLResult > 1000



/*
Combined Query for those eligible for Viral Load
*/
SELECT tmp_PatientMaster.PatientID, tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  tmp_ARTPatients.LastVisit,
  tmp_ARTPatients.StartARTDate,
  tmp_ARTPatients.AgeLastVisit,
  DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') as 'Months Since Last VL',
  CAST(IQC_LastVL.LastVLResult AS float) as LastVL
FROM tmp_PatientMaster
  LEFT JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  LEFT JOIN tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
	DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') = 12 
	OR
   (DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') <= 3 AND DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') >= 0 
	AND IQC_LastVL.LastVLResult > 1000)
	OR 
	DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') <= 6 AND DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') >= 0

/*
Combined Query for those eligible for Viral Load with duplicates removed	
*/

SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  tmp_PatientMaster.PatientID
FROM tmp_PatientMaster
  INNER JOIN tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
	DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') <= 6 AND DATEDIFF(m, tmp_ARTPatients.StartARTDate, '2017-12-31') >= 0

	UNION

SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  tmp_PatientMaster.PatientID
FROM tmp_PatientMaster
  INNER JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  WHERE 
  DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') = 12

	UNION

SELECT tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  DATEDIFF(yy, tmp_PatientMaster.DOB, '2017-12-31') as 'Age as Dec 2017',
  tmp_PatientMaster.PatientID
FROM tmp_PatientMaster
  INNER JOIN IQC_LastVL ON tmp_PatientMaster.PatientPK = IQC_LastVL.PatientPK
  WHERE DATEDIFF(m, IQC_LastVL.LastVLDate, '2017-12-31') <= 3 
  AND IQC_LastVL.LastVLResult > 1000

