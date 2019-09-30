USE IQCare_CPAD
GO

ALTER VIEW [dbo].[PatientRelationshipView]
AS
SELECT        P.Id AS PatientId, P.PersonId AS PatientPersonId, PD.FirstName AS PatientFirstName, PD.MiddleName AS PatientMiddleName, PD.LastName AS PatientLastName,
                             (SELECT        TOP (1) Name
                               FROM            dbo.LookupItem AS LI
                               WHERE        (Id = PD.Sex)) AS PatientSex, ISNULL(PD.DateOfBirth, P.DateOfBirth) AS PatientDOB, R.FirstName AS RelativeFirstName, R.MiddleName AS RelativeMiddleName, R.LastName AS RelativeLastName,
                             (SELECT        TOP (1) Name
                               FROM            dbo.LookupItem AS LI
                               WHERE        (Id = R.Sex)) AS RelativeSex, R.DateOfBirth AS RelativeDateOfBirth,
                             (SELECT        TOP (1) Name
                               FROM            dbo.LookupItem AS LI
                               WHERE        (Id = PR.RelationshipTypeId)) AS Relationship, R.Id AS RelativePersonId
FROM            dbo.Patient AS P INNER JOIN
                         dbo.PersonRelationship AS PR ON P.Id = PR.PatientId INNER JOIN
                         dbo.PersonView AS R ON R.Id = PR.PersonId INNER JOIN
                         dbo.PersonView AS PD ON PD.Id = P.PersonId
WHERE        (P.DeleteFlag = 0) AND (PR.DeleteFlag = 0) AND (R.DeleteFlag = 0)
GO

exec pr_OpenDecryptedSession
GO

SET NOCOUNT ON;

DECLARE @datacleaningUser AS INT 
DECLARE @id AS INT,@uid AS INT, @RelativesSex AS NVARCHAR(1), @ContactRelation AS NVARCHAR(50)
DECLARE @patientId AS NVARCHAR(15), @personId AS INT, @name AS NVARCHAR(50), @contactId AS INT, @contactPatientId AS NVARCHAR(15), @contactName AS NVARCHAR(50), @contactPersonId AS INT, @contactFirstName AS NVARCHAR(50)
DECLARE @CreateDate AS DATE = GETDATE()

IF NOT EXISTS(SELECT * FROM mst_User WHERE UserName = 'DataCleaning')
	EXEC Pr_Admin_SaveNewUser_Constella 'Data', 'Cleaning', 'DataCleaning', 'datacleaning', NULL, NULL
SELECT @datacleaningUser = UserId FROM mst_User WHERE UserName = 'DataCleaning'

BEGIN TRY 
	DROP table #tmpPama
END TRY
BEGIN CATCH
END CATCH

SELECT
pm.uid,
pm.Id, 
p.PersonId,
[Name], 
PatientId,
Contact_PID as ContactId,
p1.PersonId AS ContactPersonId,
REPLACE(Contact_Name,'  ', '') as ContactName,
CAST(DECRYPTBYKEY(ps2.FirstName) AS varchar(50)) AS ContactFirstName,
Contact_ccc_number as ContactPatientId,
CASE WHEN ps2.Sex = 51 THEN 'M' ELSE 'F' END AS ContactSex,
Contact_relation AS ContactRelation
INTO #tmpPama
FROM [dbo].pama_linelist pm  
INNER JOIN patient p ON p.id = pm.id
INNER JOIN patient p1 ON p1.id = pm.Contact_PID
INNER JOIN person ps2 ON p1.PersonId = ps2.Id
-- WHERE SOUNDEX(SUBSTRING(pm.[Contact_Name], 1, CHARINDEX(' ', pm.[Contact_Name])-1)) <> SOUNDEX(CAST(DECRYPTBYKEY(ps2.FirstName) AS varchar(50)))
WHERE Updated = 0 -- AND [CCC Number] IN ('13939-24532') --IS NOT NULL
--AND pm.id = 2148







--update pama_linelist SET updated = 0 WHERE id = 8613



--select * from #tmpPama
--return
SELECT @uid = min([uid]) FROM #tmpPama

WHILE @uid IS NOT NULL
BEGIN	
		BEGIN TRY 
			SELECT @id = id, @personId = PersonId, @patientId = PatientId, @name=[Name], @contactId = ContactId, @contactPatientId = ContactPatientId, @ContactPersonId = ContactPersonId, @contactName = ContactName, @contactFirstName = ContactFirstName, @RelativesSex = ContactSex, @ContactRelation = ContactRelation FROM #tmpPama WHERE uid = @uid
			
--			print @id
--			print @contactPersonId
			IF EXISTS (SELECT * FROM PersonRelationship WHERE PatientId = @id AND PersonId = @ContactPersonId)
				UPDATE PersonRelationship SET DeleteFlag = 1 WHERE PatientId = @id and PersonId = @contactPersonId

			IF EXISTS (SELECT * FROM PatientRelationshipView WHERE PatientId = @id AND (SOUNDEX(RelativeFirstName) = SOUNDEX(@ContactFirstName) OR RelativeFirstName = @ContactFirstName))
			BEGIN
				UPDATE PersonRelationship SET DeleteFlag = 1 WHERE PatientId = @id and PersonId = (
					SELECT TOP 1 RelativePersonId FROM PatientRelationshipView WHERE PatientId = @id AND SOUNDEX(RelativeFirstName) = SOUNDEX(@ContactFirstName)
				)
			END
--			print @contactPersonId
--			return
			-- Add person's relative
			DECLARE @RelationshipTypeId AS INT, @TestedPositive AS INT, @DateTestedPostive AS DATE

			SET @DateTestedPostive = (select TOP 1 HIVDiagnosisDate from PatientHivDiagnosis WHERE PatientId = @contactId AND DeleteFlag = 0)
			SET @TestedPositive = (SELECT TOP 1 id FROM LookupItem WHERE [Name] = 'Tested Positive')
			--print @DateTestedPostive
			--print @contactId
			--return

			SET @RelationshipTypeId = (SELECT TOP 1 id FROM LookupItem WHERE [Name] = @ContactRelation)

			IF @RelationshipTypeId IS NULL
			BEGIN
				IF @ContactRelation IS NULL AND @RelativesSex = 'M' 
					SET @RelationshipTypeId = (SELECT TOP 1 id FROM LookupItem WHERE [Name] = 'Father')
				ELSE IF @ContactRelation IS NULL AND @RelativesSex = 'F'
					SET @RelationshipTypeId = (SELECT Top 1 id FROM LookupItem WHERE [Name] = 'Mother')
				ELSE
					SET @RelationshipTypeId = (SELECT Top 1 id FROM LookupItem WHERE [Name] = 'Guardian')
					
			END

			INSERT INTO 
				PersonRelationship (PatientId, DeleteFlag, CreatedBy, CreateDate, RelationshipTypeId, PersonId, BaselineResult, BaselineDate)
			VALUES (@id, 0, @datacleaningUser, @CreateDate, @RelationshipTypeId, @contactPersonId, @TestedPositive, @DateTestedPostive)


			DECLARE @LinkageDate AS DATE, @ContactCCCNumber AS NVARCHAR(15)
			SELECT @LinkageDate = EnrollmentDate, @ContactCCCNumber = i.IdentifierValue 
			FROM PatientEnrollment e 
				INNER JOIN PatientIdentifier i ON e.PatientId = i.PatientId AND i.IdentifierTypeId = 1 
			WHERE e.PatientId = @contactId AND i.DeleteFlag = 0 AND e.DeleteFlag = 0

			-- update HIV Testing data
			UPDATE HIVTesting SET DeleteFlag = 1 WHERE PersonId = @contactId AND DeleteFlag = 0 
			
			INSERT INTO 
				HIVTesting (PersonId, DeleteFlag, CreatedBy, CreateDate, TestingDate, TestingResult, ReferredToCare, PatientMasterVisitId)
			VALUES (@contactPersonId, 0, @datacleaningUser, @CreateDate, @LinkageDate, @TestedPositive,1, 0)

			-- Update linkage data
			UPDATE PatientLinkage SET DeleteFlag = 1 WHERE PersonId = @contactId AND DeleteFlag = 0 

			INSERT INTO 
				PatientLinkage (PersonId, PatientId, DeleteFlag, CreatedBy, CreateDate, Enrolled, LinkageDate, CCCNumber)
			VALUES (@contactPersonId, @contactId, 0, @datacleaningUser, @CreateDate, 1, @LinkageDate, @ContactCCCNumber)

			DELETE FROM #tmpPAMA WHERE [uId] = @uId 
			UPDATE pama_linelist SET updated = 1 WHERE [uid] = @uid
			SELECT @uId = min([uId]) FROM #tmpPAMA

		END TRY
		BEGIN CATCH
			DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			print CONCAT('Error: PatientId ',  @PatientId,  ' Message: ', @ErrorMessage)
			DELETE FROM #tmpPAMA WHERE [uid] = @uid 
		END CATCH

		UPDATE pama_linelist SET updated = 2 WHERE [uid] = @uid
		SELECT @uid = min(uid) FROM #tmpPAMA
END

-- Go to relationship table and search for a patients relations via person id,
-- if exists  -- set delete flag to -0
-- if does not exists, compare first name via soundex.
-- if exists then update -- set delete flag to 0
-- add an entry to the relations table

--	select * from PatientLinkage

--DELETE from PersonRelationship WHERE CAST(CreateDate as Date) = CAST(GETDATE() AS DATE)  AND CreatedBy = 183

--DELETE FROM person_relationship WHERE deleteflag = 0

--select * from mst_User WHERE UserId = 183