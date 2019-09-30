select * from patient where ptn_pk =8979

select * from Vw_PatientCareEnd WHERE Ptn_Pk = 8979

SELECT * FROM PatientCareending WHERE PatientId =8978

SELECT * FROM Rpt_PatientCareEnded WHERE Ptn_Pk= 10535


select * from dtl_PatientTrackingCare  where ptn_pk =5614


-- DELETE Misplaced/Inconsistent Careending information
DELETE c
--SELECT r.VisitDate, c.* 
FROM RegimenMapView r INNER JOIN dtl_PatientTrackingCare c ON r.ptn_pk = c.Ptn_Pk
WHERE r.RowNumber = 1  AND r.VisitDate >= c.DateLastContact --AND r.ptn_pk = 5614
