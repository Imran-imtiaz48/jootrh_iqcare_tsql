-- select * from RegimenMapView 


-- select * from dtl_RegimenMap WHERE RegimenId IS NOT NULL


/****
Optimize the treatmentTrackerView to increase speed of execution

UPDATE THE RegimenId and RegimenLineId on dtl_regimenMap table
--------------------------------------------------------------
1. Add Column RegimenLineId on dtl_regimenMap
2. Create an SProc -sp_updateRegimenLine
3. Write a routine that updates the dtl_regimenMap by calling the sp_updateRegimenLine sproc recurssively
4. Create a trigger that updates the RegimenLine and RegimenLineId columns on the dtl_regimenMap table whenever an item is added or updated	
	(the trigger calls the sp_updateRegimenLine sproc with all the relevant arguments)
5. Update the TreatmentTrackerView to remove the code that burdens the speed of execution
*/