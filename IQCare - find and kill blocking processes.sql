select * from PatientFamilyPlanning WHERE PatientMasterVisitId =  183173


select * from PatientFamilyPlanningMethod f WHERE f.PatientFPId = 28118



select *from PatientVitals WHERE PatientId = 11427


	SELECT VitalsId,PatientId,BPDiastolic,BPSystolic,BMI,VisitDate,weight,height FROM (
		SELECT vi.Id as VitalsId, ROW_NUMBER() OVER(PARTITION BY vi.PatientId, vi.PatientMasterVisitId ORDER BY vi.CreateDate  DESC) as RowNUm, ISNULL(pmv.VisitDate, pmv.start) AS VisitDate, vi.BPDiastolic,vi.BPSystolic,vi.BMI,vi.PatientId,vi.WeightForAge,vi.WeightForHeight,vi.BMIZ,vi.Weight,vi.Height 
		FROM PatientVitals vi INNER JOIN PatientMasterVisit pmv  ON vi.PatientMasterVisitId = pmv.id 
	) v WHERE v.rowNUm =1 AND PatientId = 11427



	select * from PatientMasterVisit WHERE PatientId = 2930

	select * from PatientVitals WHERE PatientMasterVisitId = 235816

	
	select * from PatientEncounter WHERE PatientMasterVisitId = 235816

	SELECT 
     TL.resource_type,
     TL.resource_database_id,
     TL.resource_associated_entity_id,
     TL.request_mode,
     TL.request_session_id,
     WT.blocking_session_id,
     O.name AS [object name],
     O.type_desc AS [object descr],
     P.partition_id AS [partition id],
     P.rows AS [partition/page rows],
     AU.type_desc AS [index descr],
     AU.container_id AS [index/page container_id]
FROM sys.dm_tran_locks AS TL
INNER JOIN sys.dm_os_waiting_tasks AS WT 
 ON TL.lock_owner_address = WT.resource_address
LEFT OUTER JOIN sys.objects AS O 
 ON O.object_id = TL.resource_associated_entity_id
LEFT OUTER JOIN sys.partitions AS P 
 ON P.hobt_id = TL.resource_associated_entity_id
LEFT OUTER JOIN sys.allocation_units AS AU 
 ON AU.allocation_unit_id = TL.resource_associated_entity_id;



 select cmd,* from sys.sysprocesses
where blocked > 0


-- kill 106

exec sp_who2