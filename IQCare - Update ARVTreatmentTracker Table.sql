UPDATE arv
SET 
	arv.Regimen = r4.Regimen,
	arv.RegimenId = r4.RegimenId,
	arv.RegimenLine = r4.RegimenLine,
	arv.RegimenLineId = r4.RegimenLineId
FROM ARVTreatmentTracker arv
INNER JOIN (
	SELECT r3.*, i2.Id as RegimenLineId, i2.Name as RegimenLine, i.DisplayName as Regimen, i.ItemId as RegimenId 
	FROM (
		SELECT *,
		CASE sum
            WHEN 779 /*'3TC/AZT/NVP'*/ THEN CASE WHEN R.age >= 15 THEN 'AF1A' ELSE 'CF1A' END /*'AZT + 3TC + NVP'*/ 
			WHEN 760 /*'3TC/AZT/EFV'*/ THEN CASE WHEN R.age >= 15 THEN 'AF1B' ELSE 'CF1B' END /*'AZT + 3TC + EFV '*/ 
			WHEN 758 /*'3TC/AZT/DTG'*/ THEN CASE WHEN R.age >= 15 THEN 'AF1D' END /*'AZT + 3TC + DTG '*/ 
			WHEN 762 /*'3TC/NVP/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2A' ELSE 'CF4A' END /*TDF + 3TC + NVP*/ 
			WHEN 743 /*'3TC/EFV/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2B' ELSE 'CF4B' END 
			WHEN 753 /*'3TC/ATV/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2D' ELSE 'CF4D' END /*'TDF + 3TC + ATV/r'*/
			WHEN 741 /*'3TC/DTG/TDF'*/ THEN 'AF2E' /*'TDF + 3TC + DTG'*/ 
			WHEN 867 /*'3TC/LOPr/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2F' ELSE 'CF4C' END /*'TDF + 3TC + LPV/r'*/ 
			WHEN 921 /*'3TC/LPV/r/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2F' ELSE 'CF4C' END 
			/*WHEN 741 /*'3TC/RAL/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2G' END /*'TDF + 3TC + RAL'*/*/ 
			WHEN 933 /*'FTC/ATV/r/TDF'*/ THEN CASE WHEN R.age >= 15 THEN 'AF2H' END /*'TDF + FTC + ATV/r'*/ 
			WHEN 738 /*'3TC/ABC/NVP'*/ THEN CASE WHEN R.age >= 15 THEN 'AF4A' ELSE 'CF2A' END /*'ABC + 3TC + NVP'*/ 
			WHEN 719 /*'3TC/ABC/EFV'*/ THEN CASE WHEN R.age >= 15 THEN 'AF4B' ELSE 'CF2B' END /*'ABC + 3TC + EFV'*/ 
			WHEN 717 /*'3TC/ABC/DTG'*/ THEN CASE  WHEN R.age >= 15 THEN 'AF4C' ELSE 'AF4C' END /*'ABC + 3TC + DTG'*/ 
			WHEN 938 /*'3TC/AZT/LPV/r'*/ THEN CASE WHEN R.age >= 15 THEN 'AS1A' ELSE 'CS1A' END /*'AZT + 3TC + LPV/r'*/ 
			WHEN 884 /*'3TC/AZT/LOPr'*/ THEN CASE WHEN R.age >= 15 THEN 'AS1A' ELSE 'CS1A' END /*'AZT + 3TC + LPV/r'*/ 
			WHEN 770 /*'3TC/AZT/ATV'*/ THEN CASE WHEN R.age >= 15 THEN 'AS1B' ELSE 'CS1B' END /*'AZT + 3TC + ATV/r'*/ 
			WHEN 931 /*'3TC/AZT/ATV/r'*/ THEN CASE WHEN R.age >= 15 THEN 'AS1B' ELSE 'CS1B' END /*'AZT + 3TC + ATV/r'*/ 
			WHEN 921 /*'3TC/TDF/LPV/r'*/ THEN  CASE WHEN R.age >= 15 THEN 'AS2A' END /*'TDF + 3TC + LPV/r'*/ 
			WHEN 867 /*'3TC/TDF/LOPr'*/ THEN CASE WHEN R.age >= 15 THEN 'AS2A' END /*'TDF + 3TC + LPV/r'*/ 
			WHEN 753  /*'3TC/TDF/ATV'*/ THEN CASE WHEN R.age >= 15 THEN 'AS2C' END /*'TDF + 3TC + ATV/r'*/ 
			WHEN 914 /*'3TC/TDF/ATV/r'*/ THEN 'AS2C' /*'TDF + 3TC + ATV/r'*/ 
			WHEN 843 /*'3TC/ABC/LOPr'*/ THEN CASE WHEN R.age >= 15 THEN 'AS5A' ELSE 'CS2A' END /*'ABC + 3TC + LPV/r'*/ 
			WHEN 897 /*'3TC/ABC/LPV/r'*/ THEN CASE WHEN R.age >= 15 THEN 'AS5A' ELSE 'CS2A' END /*'ABC + 3TC + LPV/r'*/ 
			WHEN 890 /*'3TC/ABC/ATV/r'*/ THEN CASE WHEN R.age >= 15 THEN 'AS5B' ELSE 'CS2C' END /*'ABC + 3TC + ATV/r'*/ 
			WHEN 729 /*'3TC/ABC/ATV'*/ THEN CASE WHEN R.age >= 15 THEN 'AS5B' ELSE 'CS2C' END /*'ABC + 3TC + ATV/r'*/ 
			WHEN 1323 /*'3TC/TDF/DTG/RTV/DRV'*/ THEN 'AT2X3' /*'TDF + 3TC + DTG + DRV + RTV'*/ 
			WHEN 1609 /*'3TC/TDF/DTG/RTV/DRV'*/ THEN 'AT2X4' /*'TDF + 3TC + DTG + DRV + RTV + ETV'*/ 
			WHEN 1299 /*'3TC/TDF/DTG/RTV/DRV'*/ THEN 'AT2X5' /*'ABC + 3TC + DRV + RTV + RAL'*/ 
			WHEN 1212 /*NVP/3TC/LPV/r/TDF'*/ THEN 'CS2X1' /*'TDF + 3TC + LPV/r + NVP'*/ 
		ELSE 'Unknown' END		
		AS RegimenCode
		FROM (
			SELECT 
				r.PatientId,r.PatientMasterVisitId,r.VisitID, DATEDIFF(YY, p.DateOfBirth, v.VisitDate) as Age, r.regimenType, 
				(isnull(ascii(SUBSTRING(R.regimentype, 1, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 2, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 3, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 4, 1)), 0) + 
				isnull(ascii(SUBSTRING(R.regimentype, 5, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 6, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 7, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 8, 1)), 0) + 
				isnull(ascii(SUBSTRING(R.regimentype, 9, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 10, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 11, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 12, 1)), 0) + 
				isnull(ascii(SUBSTRING(R.regimentype, 13, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 14, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 15, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 16, 1)), 0)) +
				isnull(ascii(SUBSTRING(R.regimentype, 17, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 18, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 19, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 20, 1)), 0)  + 
				isnull(ascii(SUBSTRING(R.regimentype, 21, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 22, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 23, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 24, 1)), 0) + 
				isnull(ascii(SUBSTRING(R.regimentype, 25, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 26, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 27, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 28, 1)), 0) as sum
			FROM (
				SELECT o.ptn_pharmacy_pk,o.PatientMasterVisitId,PatientId,VisitId,
					regimenType = STUFF((
						  SELECT '/' + d.Abbreviation
						  FROM (
							SELECT DISTINCT d.ptn_pharmacy_pk, dr.Abbreviation FROM
							dtl_PatientPharmacyOrder d
							INNER JOIN Mst_Drug dr ON dr.Drug_pk = d.Drug_Pk
							WHERE dr.DrugName NOT LIKE '%cotrimo%'
							) d
						  WHERE o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
						  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
				FROM ord_PatientPharmacyOrder o
			) r 
			INNER JOIN Patient p ON p.id = r.PatientId 
			INNER JOIN PatientMasterVisit v ON v.id = r.PatientMasterVisitId
--			WHERE
--			DATEDIFF(M,v.VisitDate,GETDATE()) <=90
--			 r.PatientId = 5401
		) r
	) r3 
	INNER JOIN LookupItemView i ON r3.RegimenCode = i.ItemName 
	INNER JOIN LookupItem i2 ON i2.Name = (
			SELECT top 1 
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(MasterName,'Regimen',''),'AdultFirst','AdultARTFirst'),'AdultSecond','AdultARTSecond'),'AdultThird','AdultARTThird'),'PaedsFirst','PaedsARTFirst'),'PaedsSecond','PaedsARTSecond'),'PaedsThird','PaedsARTThird')
			FROM LookupItemView WHERE ItemName = r3.RegimenCode 
		)
) r4 ON r4.PatientId = arv.PatientId AND r4.PatientMasterVisitId = arv.PatientMasterVisitId
WHERE arv.PatientId = 38338




 -- arv.CreateDate >= '2019-01-21'
/*
select  * from LookupItem WHERE name like 'AT2X3'

SELECT * FROM (
	SELECT MasterName,RegimenType,
		(isnull(ascii(SUBSTRING(R.regimentype, 1, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 2, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 3, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 4, 1)), 0) + 
		isnull(ascii(SUBSTRING(R.regimentype, 5, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 6, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 7, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 8, 1)), 0) + 
		isnull(ascii(SUBSTRING(R.regimentype, 9, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 10, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 11, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 12, 1)), 0) + 
		isnull(ascii(SUBSTRING(R.regimentype, 13, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 14, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 15, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 16, 1)), 0)) +
		isnull(ascii(SUBSTRING(R.regimentype, 17, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 18, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 19, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 20, 1)), 0)  + 
		isnull(ascii(SUBSTRING(R.regimentype, 21, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 22, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 23, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 24, 1)), 0) + 
		isnull(ascii(SUBSTRING(R.regimentype, 25, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 26, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 27, 1)), 0) + isnull(ascii(SUBSTRING(R.regimentype, 28, 1)), 0) as sum
	FROM (
		SELECT MasterName,
			CASE WHEN ItemDisplayName IS NULL THEN NULL ELSE REPLACE((SUBSTRING(ItemDisplayName,CHARINDEX('(',ItemDisplayName)+1,LEN(ItemDisplayName) - CHARINDEX('(',ItemDisplayName))),' + ','/') END as RegimenType 
		FROM LookupItemView WHERE ItemName LIKE 'CS4X'
		-- MasterName LIKE '%LineRegimen%'
	) r
) r1 ORDER BY sum
*/