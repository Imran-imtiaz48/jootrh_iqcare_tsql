WITH data_issues_tce AS (
	SELECT di.PatientId, di.CCCNumber, di.MCHNumber, di.TINumber, di.Period, di.VisitDate, di.Height, di.Weight, di.VL, di.TCADate, di.DataIssue FROM (
		-- weight (below 200) and height (below 199) within normal limits
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Invalid Height or Weight' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.Weight >= 200 OR height >= 199 OR d.Weight <= 0 OR d.Height < 30
		UNION
		-- visit date > tcadate
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'VisitDate > TCA Date' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.VisitDate  >= d.TCADate
		UNION
		-- cd4 count without visit date
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'MISSING Visit Date' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.CD4 IS NOT NULL AND d.VisitDate IS NULL
		UNION
		-- VL without visit date
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'MISSING Visit Date' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.VL IS NOT NULL AND d.VisitDate IS NULL
		UNION
		-- date and period not matching
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Mismatched Visit Date' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE  CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) <> d.Period AND d.VisitDate IS NOT NULL
		UNION
		-- TCA month is less than Period
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Mismatched TCA Date' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE  CONCAT(YEAR(d.TCADate),RIGHT(CONCAT(0,MONTH(d.TCADate)),2)) < d.Period AND d.TCADate IS NOT NULL
		UNION
		-- TCA month is likely not correct
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'TCA Date Likely Incorrect' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE DATEDIFF(MONTH,d.VisitDate, d.TCADate) > 6 AND d.TCADate IS NOT NULL AND d.VisitDate IS NOT NULL
		UNION
		--Height present, missing weight
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Missing Weight' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.Height IS NOT NULL AND d.Weight IS NULL
		UNION
		--Weight present, missing height
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Missing Weight' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.Weight IS NOT NULL AND d.Height IS NULL
		UNION
		--Invalid regimen
		SELECT 
			d.PatientId, d.CCCNUmber, d.MCHNUmber, d.TINumber, d.PatientName, d.Period, d.VisitDate, d.Height, d.Weight, d.VL, d.CD4, d.TCADate, d.Regimen , 'Invalid Regimen' AS DataIssue
		FROM tmpImportStagingTable d
		WHERE d.VisitDate IS NOT NULL AND (ISNUMERIC(d.Regimen) = 1 OR ISDATE(d.Regimen) = 1)
		-- If regimen is provided, compare prev regimen and next regimen. If completely different, ignore
		-- SELECT TOP 1 REPLACE(SUBSTRING(t.Regimen,CHARINDEX('(',t.Regimen)+1,LEN(t.Regimen) - CHARINDEX('(',t.Regimen) - 1),' + ','/') AS Regimen FROM PatientTreatmentTrackerViewD4T t
	) di
)

SELECT 
	di.PatientId,
	di.CCCNumber,
	di.MCHNumber,
	DataIssues = STUFF((SELECT CONCAT(', ', [Period],': ',DataIssue) as DataIssues FROM data_issues_tce di1 WHERE di.patientId = di1.PatientId
	FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
FROM
(
	SELECT DISTINCT PatientId, CCCNUmber, MCHNumber FROM data_issues_tce
) di

-- GROUP BY PatientId
/*
SELECT *,
	dataIssues = STUFF((
			  SELECT ',' + fpm.FpMethod
			  FROM data_issues_tce di1
			  WHERE fpm.PatientMasterVisitId = fp.PatientMasterVisitId 
			  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
FROM data_issues_tce di
*/
return
/*UPDATE i
SET i.ReadyForUpload = 1
FROM
 tmpImportStagingTable i
LEFT JOIN  data_issues_tce d ON d.PatientId = i.PatientId AND d.Period = i.Period
WHERE d.PatientId IS NULL AND i.VisitDate IS NOT NULL

-- UPDATE tmpImportStagingTable SET ReadyForUpload = 0
*/
--SELECT * FROM tmpImportStagingTable s WHERE s.ReadyForUpload = 1 s.PatientId = 9877
-- AND s.Period = '201802' 

-- DELETE FROM tmpImportStagingTable WHERE PatientId = -1
-- SELECT * FROM tmpImportStagingTable WHERE PatientId = -1
-- SELECT * FROM tmpImportStagingTable WHERE CCCNumber = '13939-21368'

-- update [MCHDataCleaningRaw] SET updated = 0 where updated = -1
-- ALTER TABLE tmpImportStagingTable ADD ReadyForUpload SMALLINT NOT NULL DEFAULT 0
--	ALTER TABLE tmpImportStagingTable ADD ReadyForUpload SMALLINT NOT NULL DEFAULT 0

