DELETE FROM dtl_PatientPharmacyOrder WHERE id IN (
	SELECT id FROM (
		SELECT        p.Id, o.Ptn_pk,o.PatientMasterVisitId,p.CreateDate, p.dispensedQuantity,d.drugName, ROW_NUMBER() OVER(Partition by o.PatientMasterVisitId ORDER by p.Createdate ASC, p.dispensedQuantity desc) as rowNum
		FROM            dtl_PatientPharmacyOrder AS p INNER JOIN
								 Mst_Drug_Bill AS d ON p.Drug_Pk = d.Drug_pk INNER JOIN
								 ord_PatientPharmacyOrder AS o ON p.ptn_pharmacy_pk = o.ptn_pharmacy_pk
		WHERE o.PatientMasterVisitId IS NOT NULL AND d.DrugName like '%COTR%'
	) dupCtx
	WHERE rowNum = 2 
	--AND (CAST(CreateDate AS DATE) = '2018-02-12' OR DispensedQuantity = 0) 
)

DECLARE @visitId AS INT = 150026

DELETE FROM dtl_PatientPharmacyOrder WHERE id IN (
	SELECT id FROM (
		SELECT        p.Id, o.Ptn_pk,o.PatientMasterVisitId,p.CreateDate, p.dispensedQuantity,d.drugName, ROW_NUMBER() OVER(Partition by o.PatientMasterVisitId ORDER by p.Createdate ASC, p.dispensedQuantity desc) as rowNum
		FROM            dtl_PatientPharmacyOrder AS p INNER JOIN
								 Mst_Drug_Bill AS d ON p.Drug_Pk = d.Drug_pk INNER JOIN
								 ord_PatientPharmacyOrder AS o ON p.ptn_pharmacy_pk = o.ptn_pharmacy_pk
		WHERE o.PatientMasterVisitId = @visitId
	) dupCtx
)

DELETE FROM ord_PatientPharmacyOrder WHERE PatientMasterVisitId = @visitId

DELETE FROM ARVTreatmentTracker WHERE PatientMasterVisitId = @visitId

DELETE FROM PatientEncounter WHERE PatientMasterVisitId = @visitId

DELETE FROM PatientMasterVisit WHERE id = @visitId

