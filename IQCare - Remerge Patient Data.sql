IF OBJECT_ID('tempdb..#tmpUpdatePML') IS NOT NULL
	DROP TABLE #tmpUpdatePML
GO

DECLARE @Id AS INT 
DECLARE @PreferredPatientId AS INT 
DECLARE @UnPreferredPatientId AS INT 

SELECT
	ID, PreferredPatientId, UnPreferredPatientId	
INTO #tmpUpdatePML
FROM [dbo].PatientMergingLog d WHERE PreferredPatientId = 5780 OR UnpreferredPatientId = 5780

SELECT @Id = min(Id) FROM #tmpUpdatePML

WHILE @Id IS NOT NULL
BEGIN
	SELECT @PreferredPatientId = PreferredPatientId, @UnPreferredPatientId = UnPreferredPatientId FROM #tmpUpdatePML WHERE Id = @id
	if (SELECT COUNT(*) FROM gcPatientView WHERE Id = @PreferredPatientId) > 0
		EXEC sp_MergePatientData @PreferredPatientId, @UnPreferredPatientId
	DELETE FROM #tmpUpdatePML WHERE Id = @Id
	SELECT @Id = min(Id) FROM #tmpUpdatePML
END
GO

-- SELECT * from #tmpUpdatePML


-- select * from mst_User WHERE UserID IN (6,49)


-- select * from gcPatientView WHERE Id = 7654
/*
SELECT p1.Id,p1.PreferredPatientId,p1.UnPreferredPatientId, p1.CreatedBy, p2.PreferredPatientId,p2.UnPreferredPatientId, p2.CreatedBy FROM PatientMergingLog P1 INNER JOIN PatientMergingLog P2 ON p1.PreferredPatientId = p2.UnPreferredPatientId AND p1.UnPreferredPatientId = p2.PreferredPatientId
AND p1.Id <> p2.ID
*/
