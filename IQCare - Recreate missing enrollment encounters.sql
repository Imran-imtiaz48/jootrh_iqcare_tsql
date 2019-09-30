-- Add Appointment
DECLARE @VisitDate AS DATE = '2019-05-29'
DECLARE @PatientId AS INT --= 1

SELECT id as PatientId 
INTO #tmpptn
FROM patient WHERE ptn_pk IN (
5614
)

SET @PatientId = (SELECT MAX(PatientId) FROM #tmpptn)

WHILE @PatientId IS NOT NULL
BEGIN

	SET @VisitDate = (SELECT MAX(e.EnrollmentDate) FROM PatientEnrollment e WHERE PatientId = @PatientId AND DeleteFlag = 0)
	DECLARE @PatientMasterVisitId AS INT, @VisitId AS INT, @UserId AS INT, @EncounterId INT, @dcModelId INT


	SELECT TOP 1
			@PatientMasterVisitID = v.Id, @UserID = v.CreatedBy, @VisitDate = CAST(v.VisitDate AS DATE)
	FROM PatientMasterVisit v
	INNER JOIN lnk_UserGroup lg ON v.CreatedBy = lg.UserID
	WHERE 
		PatientId = @patientId AND (ABS(DATEDIFF (DAY, ISNULL(VisitDate,[Start]), @VisitDate)) <= 5)
		AND  (lg.GroupID = 5 or lg.GroupID = 7) -- Encounters by nurses and clinicians

	IF	@@ROWCOUNT = 0 
		exec sp_getVisit @VisitDate, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT


	-- Create CCC encounter if it doesn't exist
	DECLARE @encounterTypeId AS INT = 1482
	exec sp_getEncounter @PatientMasterVisitId, @encounterTypeId, @PatientId, @userId, @EncounterId OUT

	DELETE FROM #tmpptn WHERE PatientId = @PatientId
	SET @PatientId = (SELECT MAX(PatientId) FROM #tmpptn)

END

drop table #tmpptn
