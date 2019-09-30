	-- Update Carended Status in the Enrollment table for patients with carending information updated
	UPDATE pe
	SET pe.CareEnded = 1
	FROM PatientEnrollment pe INNER JOIN
	PatientCareending pc ON pe.PatientId = pc.PatientId
	WHERE pc.DeleteFlag = 0  AND pe.CareEnded = 0 -- AND pc.PatientId = 1654


	-- Delete duplicate patient care endings
	DELETE FROM PatientCareending WHERE id IN (
		SELECT id FROM (
			SELECT *, ROW_NUMBER() OVER(PARTITION BY PatientId, ExitReason, ExitDate ORDER BY PatientId) AS rown FROM PatientCareending
		) pce WHERE rown > 1
	)
	
	-- Soft-delete duplicated Careending records
	UPDATE PatientCareending SET DeleteFlag = 1 WHERE id IN (
		SELECT id FROM (
			SELECT *, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY ExitDate DESC, Createdate DESC) AS rown FROM PatientCareending WHERE DeleteFlag = 0
		) pce WHERE rown > 1
	)
	
	select * from PatientCareending WHERE PatientId = 36

	-- Update careending information for careended patients
	UPDATE pceu
	SET pceu.DeleteFlag = 0
	-- SELECT *
	FROM 
	PatientCareEnding pceu
	INNER JOIN 
	(
		SELECT id, PatientID FROM (
			SELECT id, patientId, ROW_NUMBER() OVER (PARTITION BY PatientID ORDER BY Exitdate DESC, CreateDate DESC) AS rown FROM PatientCareending WHERE DeleteFlag = 1 
		) pce WHERE rown = 1
	) pce ON pce.PatientId = pceu.PatientId
	INNER JOIN 
	(
		SELECT pe.PatientId FROM PatientEnrollment pe WHERE CareEnded = 1 AND pe.PatientId NOT IN (
			SELECT PatientId FROM PatientCareending pce WHERE pce.PatientId = pe.PatientId AND DeleteFlag = 0
		) 		
	) pe ON pe.PatientId = pceu.PatientId
--	WHERE pceu.PatientId = 3347

	-- Soft delete duplicated patient enrollments
	UPDATE peu
	SET peu.DeleteFlag = 1
	-- SELECT *
	FROM PatientEnrollment peu
	INNER JOIN (
		SELECT * FROM (
			SELECT ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate) rown,* FROM PatientEnrollment WHERE DeleteFlag = 0 AND ServiceAreaId = 1 -- WHERE PatientId = 9878
		) pe WHERE rown > 1
	) pe ON pe.id = peu.id
	--WHERE pe.PatientId = 12228

	UPDATE PatientEnrollment SET DeleteFlag = 0 WHERE PatientId IN (
		select PatientId from  PatientEnrollment
		GROUP BY PatientId
		HAVING COUNT(PatientId) > 1 
	)
	;WITH careending_cte AS (
	SELECT * FROM (
		SELECT 
			pce.PatientId, pce.CreateDate as PCECreate, pce.ExitDate, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY Exitdate DESC) rown 
		FROM PatientCareending pce
		WHERE pce.DeleteFlag = 0
	) ce WHERE rown = 1
),

last_visit_cte AS (
	SELECT * FROM (
		SELECT v.PatientId, v.VisitDate, ROW_NUMBER() OVER (PARTITION BY v.PatientId ORDER BY v.VisitDate DESC) AS rown 
		FROM PatientMasterVisit v 
		INNER JOIN PatientEncounter p ON v.id = p.PatientMasterVisitId AND v.PatientId = p.PatientId
	) v WHERE v.rown = 1
)


-- UPDATE wrongly careeded clients
;WITH careending_cte AS (
	SELECT * FROM (
		SELECT 
			pce.PatientId, pce.CreateDate as PCECreate, pce.ExitDate, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY Exitdate DESC) rown 
		FROM PatientCareending pce
		WHERE pce.DeleteFlag = 0
	) ce WHERE rown = 1
),

last_visit_cte AS (
	SELECT * FROM (
		SELECT v.PatientId, v.VisitDate, ROW_NUMBER() OVER (PARTITION BY v.PatientId ORDER BY v.VisitDate DESC) AS rown 
		FROM PatientMasterVisit v 
		INNER JOIN PatientEncounter p ON v.id = p.PatientMasterVisitId AND v.PatientId = p.PatientId
	) v WHERE v.rown = 1
)

UPDATE pce
SET pce.DeleteFlag = 1
FROM
PatientCareending pce -- SET DeleteFlag = 0
INNER JOIN ( 
	SELECT c.PatientId, c.ExitDate,v.VisitDate FROM careending_cte c INNER JOIN last_visit_cte v ON c.PatientId = v.PatientId AND v.VisitDate > c.ExitDate
) p ON p.PatientId = pce.PatientId
--WHERE p.PatientId = 726
AND pce.DeleteFlag = 0


UPDATE pe
SET pe.CareEnded = 0
FROM
PatientEnrollment pe -- SET DeleteFlag = 0
INNER JOIN (
	SELECT * FROM PatientEnrollment WHERE CareEnded = 1 AND PatientId  NOT IN (
		SELECT PatientId FROM PatientCareending WHERE DeleteFlag = 0 
	) 
) p ON p.PatientId = pe.PatientId
--WHERE pe.PatientId = 726
AND pe.CareEnded = 1 

-- select * from gcPatientView2 where EnrollmentNumber like '%24027%'