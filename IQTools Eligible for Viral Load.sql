WITH all_patients_cte AS (
	SELECT tp.*,p.Id FROM [IQTools_KeHMIS].dbo.tmp_PatientMaster tp INNER JOIN gcPatientView p ON tp.PatientPK = p.ptn_pk
	),
patient_artintitiation_dates_cte AS (
	SELECT PatientId, min(ARTDate) as ARTInitiationDate FROM (
		SELECT        PatientId, ARTInitiationDate as ARTDate
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN (SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder WHERE (Prophylaxis = 0)) AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL
	) PatientARTdates WHERE ARTdate <= '2018-04-30'
	GROUP BY patientId
),
last_vl_cte AS (
	SELECT * FROM  (
			SELECT   ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY lastVlDate DESC) as RowNum, patientId,lastVlDate,lastVLResult
							FROM (
									SELECT        patientId, SampleDate AS lastVlDate, ResultValues AS lastVLResult
									FROM            PatientLabTracker
									WHERE        (Results = 'Complete') AND (SampleDate < '2018-04-01') AND (LabTestId = 3)
									UNION
									SELECT        p.Id AS PatientId, tvl.LastVLDate, tvl.LastVLResult
									FROM            IQTools_KeHMIS.dbo.IQC_LastVL AS tvl INNER JOIN
															 Patient AS p ON p.ptn_pk = tvl.PatientPK
									WHERE        (tvl.LastVLDate < '2018-04-01')
							) all_vl
				) vl
	WHERE vl.RowNum = 1

),
routine_vl_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, '2018-04-01') AS 'Months Since Last VL', 'Routine VL' as Reason FROM last_vl_cte WHERE (DateDiff(m, LastVLDate, '2018-04-01') = 12)
),
high_vl_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, '2018-04-01') AS 'Months Since Last VL', 'High VL' as Reason FROM last_vl_cte WHERE lastVLResult > 1000 AND DateDiff(m, LastVLDate, '2018-04-01') = 3
),
initial_vl_cte AS (
	SELECT PatientId,ARTInitiationDate, 'FirstVl' as 'Reason' FROM patient_artintitiation_dates_cte WHERE (DateDiff(m, ARTInitiationDate, '2018-04-01') = 6)
),
vl_cte AS (
	SELECT PatientId FROM routine_vl_cte
	UNION
	SELECT PatientId FROM high_vl_cte
	UNION
	SELECT PatientId FROM initial_vl_cte
)

--select * from PatientLabTracker WHERE PatientId = 1211

--select * from IQTools_KeHMIS.dbo.IQC_LastVL WHERE PatientPK = 1212

select * from last_vl_cte WHERE PatientId IN (
	select id from gcPatientView WHERE EnrollmentNumber = '23139-13'
)
 
--select p.PatientID,r.* from routine_vl_cte r INNER JOIN all_patients_cte p ON P.id = r.patientId

-- select * from high_vl_cte
--select * from initial_vl_cte
/*
SELECT p.PatientId,p.Gender,p.DOB, lv.lastVlDate, lv.lastVLResult, a.ARTInitiationDate as ARTStartDate, DateDiff(m, ARTInitiationDate, '2018-04-01') AS 'Months Since ART Start', DateDiff(m, LastVLDate, '2018-04-01') AS 'Months Since Last VL' FROM all_patients_cte p 
LEFT JOIN patient_artintitiation_dates_cte a ON p.id = a.PatientId
LEFT JOIN last_vl_cte lv ON p.Id = lv.patientId
INNER JOIN vl_cte v ON p.id = v.patientId 
*/

/*

SELECT tmp_PatientMaster.PatientID,
  tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  tmp_ARTPatients.LastVisit,
  tmp_ARTPatients.StartARTDate,
  tmp_ARTPatients.AgeLastVisit,
  DateDiff(m, IQC_LastVL.LastVLDate, '2018-04-01') AS 'Months Since Last VL',
  CAST(IQC_LastVL.LastVLResult AS float) AS LastVL
FROM [IQTools_KeHMIS].dbo.tmp_PatientMaster
  LEFT JOIN (SELECT *
  FROM (SELECT CAST(Row_Number() OVER (PARTITION BY p.PatientPK ORDER BY
      p.OrderedbyDate DESC) AS Varchar) AS RowID,
      p.PatientPK,
      CAST(Floor(p.TestResult) AS int) LastVLResult,
      CASE WHEN p.TestName = 'Viral Load' THEN p.TestResult
        WHEN p.TestName = 'ViralLoad Undetectable' THEN 'Undetectable' ELSE NULL
      END AS LastVL,
      p.OrderedbyDate LastVLDate
    FROM [IQTools_KeHMIS].dbo.tmp_Labs p
    WHERE p.OrderedbyDate <= '2018-04-01' AND p.TestName LIKE '%Viral%') AS LastVLTbl
  WHERE LastVLTbl.RowID = 1) AS IQC_LastVL ON tmp_PatientMaster.PatientPK =
    IQC_LastVL.PatientPK
  LEFT JOIN [IQTools_KeHMIS].dbo.tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
(
	(DateDiff(m, IQC_LastVL.LastVLDate, '2018-04-01') = 12)
	-- OR (IQC_LastVL.LastVLResult > 1000 AND DateDiff(m, IQC_LastVL.LastVLDate, '2018-04-01') = 3)
    --OR (DateDiff(m, tmp_ARTPatients.StartARTDate, '2018-04-01') = 6)
 )
AND
 tmp_PatientMaster.PatientPk = 2734
*/