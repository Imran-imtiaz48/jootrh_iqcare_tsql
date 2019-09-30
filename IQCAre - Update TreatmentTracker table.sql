SELECT * FROM PatientTreatmentTrackerView t WHERE PatientId = 32794
--AND Regimen IS NOT NULL  AND YEAR(t.RegimenStartDate) >= 2000
ORDER BY
RegimenStartDate ASC


SELECT * FROM PatientMasterVisit where id = 178811


select * from ARVTreatmentTracker WHERE PatientMasterVisitId = 174191


-- THESE 2 QUERIES SHOULD BE RUN CONCURRENTLY

UPDATE
    a
SET
    a.RegimenStartDate = o.DispensedByDate
FROM
    ARVTreatmentTracker AS a
    INNER JOIN ord_PatientPharmacyOrder AS o
        ON a.PatientMasterVisitId = o.PatientMasterVisitId AND a.PatientId = o.PatientId
WHERE a.RegimenStartDate IS NULL


-- DELETE/UPDATE CTX ONLY DISPENSES
UPDATE a 
SET 
	a.RegimenStartDate = NULL,
	a.RegimenLineId = 0
FROM ARVTreatmentTracker a 
INNER JOIN (
	SELECT PatientMasterVisitId FROM ord_PatientPharmacyOrder WHERE ptn_pharmacy_pk IN (
		SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder d WHERE d.ptn_pharmacy_pk IN (
			SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder GROUP BY ptn_pharmacy_pk
			HAVING Count(*) = 1
		) AND d.Drug_Pk IN (select Drug_pk from Mst_Drug WHERE drugname LIKE '%cotrimox%')
	) AND PatientMasterVisitId IS NOT NULL
) b ON b.PatientMasterVisitId = a.PatientMasterVisitId


DELETE a
FROM ARVTreatmentTracker a 
INNER JOIN (
	SELECT PatientMasterVisitId FROM ord_PatientPharmacyOrder WHERE ptn_pharmacy_pk IN (
		SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder d WHERE d.ptn_pharmacy_pk IN (
			SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder GROUP BY ptn_pharmacy_pk
			HAVING Count(*) = 1
		) AND d.Drug_Pk IN (select Drug_pk from Mst_Drug WHERE drugname LIKE '%cotrimox%')
	) AND PatientMasterVisitId IS NOT NULL
) b ON b.PatientMasterVisitId = a.PatientMasterVisitId



SELECT PatientMasterVisitId FROM ord_PatientPharmacyOrder WHERE ptn_pharmacy_pk IN (
	SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder d WHERE d.ptn_pharmacy_pk IN (
		SELECT ptn_pharmacy_pk FROM dtl_PatientPharmacyOrder GROUP BY ptn_pharmacy_pk
		HAVING Count(*) > 1
	) AND d.Drug_Pk IN (select Drug_pk from Mst_Drug WHERE drugname LIKE '%cotrimox%')
) AND PatientMasterVisitId IS NOT NULL


-- select * from dtl_PatientPharmacyOrder d WHERE ptn_pharmacy_pk IN 


-- FETCH
SELECT DATEDIFF(YY,p.DateOfBirth,RegimenStartDate), * 
FROM ARVTreatmentTracker  arv
INNER JOIN Patient p ON p.Id = arv.PatientId
WHERE PatientMasterVisitId IN (
	SELECT PatientMasterVisitId
--	SELECT o.PatientId,dr.Drug_pk,dr.DrugName,o.DispensedByDate,PatientMasterVisitId  
	FROM ord_PatientPharmacyOrder o WHERE ptn_pharmacy_pk IN (
		SELECT o.ptn_pharmacy_pk
		FROM ord_PatientPharmacyOrder  o
		INNER JOIN dtl_PatientPharmacyOrder d ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk 
		INNER JOIN Mst_Drug dr ON dr.Drug_pk = d.Drug_Pk
		WHERE DrugName NOT LIKE '%Cotrimo%' AND (DrugName LIKE '%DRV/RTV%' OR DrugName LIKE '%RAL%' OR DrugName LIKE '%Tenofovir DF/Lamivudine%' OR DrugName LIKE '%TDF/FTC%' OR DrugName LIKE '%TLD%' )
		AND o.PatientId = 9210 
		GROUP BY o.ptn_pharmacy_pk
		HAVING count(*) > 1
	)
--	ORDER BY OrderedByDate DESC
) AND
DATEDIFF(YY,p.DateOfBirth,RegimenStartDate) >= 15

-- UPDATE
UPDATE arv
SET 
	arv.RegimenId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName LIKE '%TDF + FTC + DRV + RTV + RAL%'),
	arv.RegimenLineId = (SELECT top 1 id FROM LookupItem WHERE Name LIKE '%AdultARTThirdLine%')
FROM ARVTreatmentTracker  arv
INNER JOIN Patient p ON p.Id = arv.PatientId
WHERE PatientMasterVisitId IN (
	SELECT PatientMasterVisitId
	FROM ord_PatientPharmacyOrder o WHERE ptn_pharmacy_pk IN (
		SELECT o.ptn_pharmacy_pk
		FROM ord_PatientPharmacyOrder  o
		INNER JOIN dtl_PatientPharmacyOrder d ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk 
		INNER JOIN Mst_Drug dr ON dr.Drug_pk = d.Drug_Pk
		WHERE DrugName NOT LIKE '%Cotrimo%' 
		AND (DrugName LIKE '%DRV/RTV%' OR DrugName LIKE '%RAL%' OR DrugName LIKE '%TDF/FTC%')
		AND o.PatientId = 3201
		GROUP BY o.ptn_pharmacy_pk
		HAVING count(*) > 1
	)
) AND
DATEDIFF(YY,p.DateOfBirth,RegimenStartDate) >= 15


-- UPDATE 
UPDATE arv
SET 
	arv.RegimenId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName LIKE '%DRV + RTV + TDF + 3TC + DTG%'),
	arv.RegimenLineId = (SELECT top 1 id FROM LookupItem WHERE Name LIKE '%AdultARTThirdLine%')
FROM ARVTreatmentTracker  arv
INNER JOIN Patient p ON p.Id = arv.PatientId
WHERE PatientMasterVisitId IN (
	SELECT PatientMasterVisitId --,OrderedByDate
	FROM ord_PatientPharmacyOrder o WHERE ptn_pharmacy_pk IN (
		SELECT o.ptn_pharmacy_pk --,count(*)
		FROM ord_PatientPharmacyOrder  o
		INNER JOIN dtl_PatientPharmacyOrder d ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk 
		INNER JOIN Mst_Drug dr ON dr.Drug_pk = d.Drug_Pk
		WHERE DrugName NOT LIKE '%Cotrimo%'  AND DrugName NOT LIKE '%LPV/r%' AND DrugName NOT LIKE '%RAL%'
		AND (DrugName LIKE '%DRV/RTV%' OR DrugName LIKE '%TLD%' OR DrugName LIKE '%Ritonavir-RTV300%' OR DrugName LIKE '%Dolutegravir%' OR DrugName LIKE '%Tenofovir DF/Lamivudine%')
		AND o.PatientId = 2641
		GROUP BY o.ptn_pharmacy_pk
		HAVING count(*) > 1
	)
) AND
DATEDIFF(YY,p.DateOfBirth,RegimenStartDate) >= 15


-- UPDATE 
UPDATE arv
SET 
	arv.RegimenId = (SELECT top 1 Id FROM LookupItem WHERE DisplayName LIKE '%DRV + RTV + TDF + 3TC + DTG%'),
	arv.RegimenLineId = (SELECT top 1 id FROM LookupItem WHERE Name LIKE '%AdultARTThirdLine%')
FROM ARVTreatmentTracker  arv
INNER JOIN Patient p ON p.Id = arv.PatientId
WHERE PatientMasterVisitId IN (
	SELECT PatientMasterVisitId --,OrderedByDate
	FROM ord_PatientPharmacyOrder o WHERE ptn_pharmacy_pk IN (
		SELECT o.ptn_pharmacy_pk --,count(*)
		FROM ord_PatientPharmacyOrder  o
		INNER JOIN dtl_PatientPharmacyOrder d ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk 
		INNER JOIN Mst_Drug dr ON dr.Drug_pk = d.Drug_Pk
		WHERE DrugName NOT LIKE '%Cotrimo%'  AND DrugName NOT LIKE '%LPV/r%' AND DrugName NOT LIKE '%DTG%'
		AND (DrugName LIKE '%DRV/RTV%' OR DrugName LIKE '%Raltegravir-RA%' OR DrugName LIKE '%Ritonavir-RTV300%' OR DrugName LIKE '%Tenofovir DF/Lamivudine%')
		AND o.PatientId = 5795
		GROUP BY o.ptn_pharmacy_pk
		HAVING count(*) > 1
	)
) AND
DATEDIFF(YY,p.DateOfBirth,RegimenStartDate) >= 15


UPDATE ARVTreatmentTracker SET RegimenId = '137', RegimenLineId='215' WHERE PatientMasterVisitId = 163868

select * from ARVTreatmentTracker WHERE PatientMasterVisitId = 169618



SELECT top 1 * FROM LookupItem WHERE Name LIKE '%AdultARTThirdLine%'
SELECT top 1 Id FROM LookupItem WHERE Name LIKE '%PaedsARTThirdLine%'

SELECT * FROM LookupItemView WHERE
 ( DisplayName LIKE '%DRV/RTV%' OR DisplayName LIKE '%TLD%' OR DisplayName LIKE '%%' OR DisplayName LIKE '%FTC%') 
-- DisplayName LIKE '%FTC%'
AND MasterName LIKE '%line%'

SELECT * FROM LookupItemView WHERE( ItemName LIKE '%AdultARTThirdLine%' )

SELECT * FROM ARVTreatmentTracker WHERE RegimenId IN (141,169,174)

UPDATE ARVTreatmentTracker SET RegimenId = 1596, RegimenLineId=213  WHERE PatientMasterVisitId IN ( 153494,173682,177360)


SELECT * FROM ARVTreatmentTracker WHERE PatientId = 49

