select /*orderStatus=2,*/DispensedBy=OrderedBy,DispensedByDate=OrderedByDate FROM ord_PatientPharmacyOrder WHERE OrderStatus = 1

UPDATE ord_PatientPharmacyOrder SET orderStatus=2, DispensedBy=OrderedBy,DispensedByDate=OrderedByDate WHERE OrderStatus = 1



select * from RegimenMapView R INNER JOIN
                         ord_PatientPharmacyOrder o ON o.VisitID = R.Visit_Pk
WHERE R.patientId = 10432


select * from dtl_RegimenMap WHERE Visit_Pk = 734124


insert into dtl_RegimenMap (Ptn_Pk, LocationID, Visit_Pk, RegimenType, OrderID, DeleteFlag, UserID, CreateDate) VALUES (
10431, 754,734124,'ABC/3TC/LPV/r',192412,0,1,GETDATE())


--GEt hanging Orders 
-- Fetch entries in ord_PatientPharmacyOrder not existing in dtl_RegimenMap - Visit_PK,Ptn_pk
INSERT INTO dtl_RegimenMap (Ptn_Pk, LocationID, Visit_Pk, RegimenType, OrderID, DeleteFlag, UserID, CreateDate) 
SELECT DISTINCT Ptn_pk,754 as LocationId,VisitId as Visit_Pk,Abbreviation as RegimenType,ptn_pharmacy_pk as OrderId,0 as DeleteFlag,1 as UserId,GETDATE() as CreateDate 
FROM (
	SELECT d.Abbreviation,o.* FROM ord_PatientPharmacyOrder o LEFT JOIN dtl_RegimenMap r ON o.Ptn_pk = r.Ptn_Pk AND o.VisitID = r.Visit_Pk 
	INNER JOIN dtl_PatientPharmacyOrder od ON od.ptn_pharmacy_pk = o.ptn_pharmacy_pk 
	INNER JOIN Mst_Drug d ON d.Drug_pk = od.Drug_Pk AND Abbreviation IS NOT NULL
	INNER JOIN gcPatientView g ON g.ptn_pk = o.Ptn_pk
	WHERE r.Ptn_Pk IS NULL
) reg

select top 2 * from dtl_RegimenMap ORDER BY CreateDate DESC 

select * from gcPatientView WHERE ptn_pk= '5595'

select * from ord_Visit WHERE Visit_Id = 726303

select * from PatientTreatmentTrackerView WHERE ptn_pk = 5595

