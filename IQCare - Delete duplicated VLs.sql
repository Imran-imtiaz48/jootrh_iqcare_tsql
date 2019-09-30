/*

--[PatientMasterVisit]
ord_Visit
-- dtl_LabOrderTest
-- ord_LabOrder
-- dtl_LabOrderTestResult
-- PatientLabTracker
-- PatientEncounter


SELECT PatientID,VisitDate, Count(*) as Visits FROM 
(
	SELECT PatientId, CAST(VisitDate AS DATE) as VisitDate FROM [PatientMasterVisit] WHERE CreatedBy = 114
) d GROUP BY PatientID, VisitDate HAVING Count(*) > 1


SELECT Ptn_Pk,VisitDate, Count(*) as Visits FROM 
(
	SELECT Ptn_Pk, CAST(VisitDate AS DATE) as VisitDate FROM ord_Visit WHERE UserID = 114 and TypeofVisit = 70
) d GROUP BY Ptn_Pk, VisitDate HAVING Count(*) > 1

SELECT top 100 * FROM dtl_LabOrderTest   WHERE UserID = 114 AND LabTestId = 3

SELECT Ptn_Pk,OrderDate, Count(*) as Visits FROM 
(
	SELECT Ptn_Pk, CAST(OrderDate AS DATE) as OrderDate FROM ord_LabOrder   WHERE UserID = 114 AND ClinicalOrderNotes = 'IL lab order' AND OrderStatus = 'completed'
) d GROUP BY Ptn_Pk, OrderDate HAVING Count(*) > 1

SELECT * FROM PatientMasterVisit WHERE PatientId = 1925	and CAST(VisitDate as DATE) = '2018-06-25'

SELECT * FROM PatientMasterVisit WHERE PatientId = 11650	and CAST(VisitDate as DATE) = '2018-08-06'

SELECT * FROM ord_Visit WHERE Ptn_Pk = 7399	and CAST(VisitDate as DATE) = '2018-07-17'

SELECT * FROM dtl_LabOrderTest WHERE Ptn_Pk = 7399	and CAST(VisitDate as DATE) = '2018-07-17'
*/

/*
select * from #tmpRemoveDuplicateVLResults

delete from dtl_LabOrderTestResult WHERE LabOrderId = 202511
delete from dtl_LabOrderTest WHERE LabOrderId = 202511
delete from ord_LabOrder WHERE Id = 202511
delete from PatientLabTracker WHERE LabOrderId = 202511
delete from PatientEncounter WHERE PatientMasterVisitId = 100023 aND EncounterTypeId = 1503
delete from PatientMasterVisit WHERE Id = 100023 aND CreatedBy = 114

select * from PatientEncounter WHERE PatientMasterVisitId = 100023 aND EncounterTypeId = 1503
select * from PatientMasterVisit WHERE Id = 100023 

-- Lab Encounter 1503
-- PatientId = 607
SELECT * FROM dtl_LabOrderTestResult WHERE LabOrderId = 214070

update PatientLabTracker SET ResultUnits = 'copies/ml' WHERE id  =  26580

select * from ord_LabOrder WHERE PatientId = 607


update ord_LabOrder SET OrderStatus = 'Complete' WHERE OrderStatus = 'Completed'

select * from PatientLabTracker WHERE PatientId = 607

SELECT * FROM LookupItemView WHERE MasterName LIKE '%VisitType%'

select * from gcPatientView WHERE id = 607


exec sp_getPatientEncounterHistory 607
/
*/


USE IQCARE_CPAD
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('tempdb..#tmpRemoveDuplicateVLResults') IS NOT NULL
	DROP TABLE #tmpRemoveDuplicateVLResults
GO

DECLARE @LabOrderId AS INT
DECLARE @PatientMasterVisitId AS INT

SELECT LabOrderId,PatientId,PatientMasterVisitId,SampleDate,Results,ResultValues,CreatedBy
INTO #tmpRemoveDuplicateVLResults
FROM (
	SELECT  ROW_NUMBER() OVER (PARTITION BY patientId,SampleDate ORDER BY patientId,Results,CreatedBy) as rowNum, PatientId,SampleDate,LabOrderId,Results,ResultValues,PatientMasterVisitId,CreatedBy FROM PatientLabTracker WHERE LabName = 'Viral Load' --AND CreatedBy = 114
) d WHERE rowNum > 1 AND PAtientId IN (6860)

SELECT * FROM #tmpRemoveDuplicateVLResults

SELECT @LabOrderId = min(LabOrderId) FROM #tmpRemoveDuplicateVLResults

WHILE @LabOrderId IS NOT NULL
BEGIN
	SET ROWCOUNT 0
	
	SELECT 
		@LabOrderId = LabOrderId, @PatientMasterVisitId = PatientMasterVisitId
	FROM #tmpRemoveDuplicateVLResults  WHERE LabOrderId = @LabOrderId

	DELETE FROM dtl_LabOrderTestResult WHERE LabOrderId = @LabOrderId
	DELETE FROM dtl_LabOrderTest WHERE LabOrderId = @LabOrderId
	DELETE FROM ord_LabOrder WHERE Id = @LabOrderId
	DELETE FROM PatientLabTracker WHERE LabOrderId = @LabOrderId
	DELETE FROM PatientEncounter WHERE PatientMasterVisitId = @PatientMasterVisitId AND EncounterTypeId = 1503
	DELETE FROM PatientMasterVisit WHERE Id = @PatientMasterVisitId -- AND CreatedBy = 114


	DELETE FROM #tmpRemoveDuplicateVLResults WHERE LabOrderId = @LabOrderId
	SELECT @LabOrderId = min(LabOrderId) FROM #tmpRemoveDuplicateVLResults
END
