USE IQCARE_CPAD
GO

IF OBJECT_ID('tempdb..#tmpUpdateIPT') IS NOT NULL
	DROP TABLE #tmpUpdateIPT
GO

exec pr_OpenDecryptedSession
GO

SELECT
	PatientId as FullCCCNumber,
	CASE WHEN LEN(PatientId) = 11 AND PatientId LIKE '13939%' THEN --To match values like 13939-26222
		(SUBSTRING(PatientId,CHARINDEX('-', PatientId)+1, LEN(PatientId)))  
	ELSE 
		(SUBSTRING(PatientId,1, (LEN(PatientId) - CHARINDEX('-', REVERSE(PatientId))))) 
	END  
	as cccNumber,
	DateStartedIpt, Outcome,[Outcome Date] as OutcomeDate, [Reasons For Discontinuation] as ReasonsForDiscontinuation, d.Sex, d.PatientName
INTO #tmpUpdateIPT
FROM [dbo].[IQCareIPTLineList] d WHERE Updated = 0 AND DateStartedIpt IS NOT NULL AND YEAR(DateStartedIPT) > 2000 AND PatientId IS NOT NULL --AND PatientId IN ('13939-00795') --IS NOT NULL

-- Select * from #tmpUpdateIPT

DECLARE @DateStartedIpt  AS DATE
DECLARE @Outcomestring AS NVARCHAR(50)
DECLARE @Outcome AS INT
DECLARE @OutcomeDate as DATE
DECLARE @ReasonsForDiscontinuation as NVARCHAR(100)
DECLARE @FullcccNumber as NVARCHAR(50)
DECLARE @cccNumber as NVARCHAR(50)
DECLARE @sex as INT
DECLARE @firstName as NVARCHAR(50)

DECLARE @rc AS INT
DECLARE @ptnPk AS INT
DECLARE @PatientId AS INT

DECLARE @PatientMasterVisitId AS INT
DECLARE @VisitId AS INT 
DECLARE @UserId AS INT 
DECLARE @Success AS TINYINT


SELECT @FullcccNumber = min(FullCCCNumber) FROM #tmpUpdateIPT

SELECT 
	@sex = (CASE WHEN sex = 'M' THEN 51 ELSE 52 END), @cccNumber = CCCNUmber, @fullCCCNumber = FullCCCNumber, @firstName = (SUBSTRING([PatientName],0,CHARINDEX(' ', [PatientName]))),  
	@DateStartedIpt = DateStartedIpt,@Outcomestring = Outcome, @OutcomeDate = OutcomeDate, @ReasonsForDiscontinuation = ReasonsForDiscontinuation
FROM #tmpUpdateIPT  WHERE FullcccNumber = @FullcccNumber

set rowcount 0

WHILE @fullcccNumber IS NOT NULL
BEGIN
			-- Get Patient Id 
			SELECT 
				@PatientId = id, @ptnpk = ptn_pk
			FROM gcPatientView p
			WHERE EnrollmentNumber = @fullcccNumber

			set @rc = @@ROWCOUNT
			if @rc = 0
			BEGIN
				SELECT 
					@PatientId = id, @ptnpk = ptn_pk
				FROM gcPatientView p
				WHERE EnrollmentNumber LIKE CONCAT('%',@cccNumber,'%') AND p.Sex = @sex AND CONCAT(Firstname,' ',MiddleName,'',LastName) LIKE CONCAT('%',@firstName,'%')
			END

			IF @rc = 1 OR @@ROWCOUNT = 1 -- Begin updating IPT Data
			BEGIN
				-- upload excel
				-- run sps
					-- get_visit
					-- updateIPT

				exec sp_getVisit @DateStartedIpt, @PatientId, @PatientMasterVisitId OUT, @VisitId OUT, @UserId OUT

				IF @Outcomestring LIKE '%comp%'
					SET @Outcome = 525
				ELSE 
					IF @Outcomestring LIKE '%trans%'
						SET @Outcome = 529
					ELSE
						IF @Outcomestring LIKE '%DISCON%'
							SET @Outcome = 527
						ELSE
							IF @OutcomeString LIKE '%Lost%'
								SET @Outcome = 526
							ELSE
								IF @OUtcomeString LIKE '%DIE%'
									SET @Outcome = 528
								ELSE
									SET @Outcome = 0
										
				exec sp_updateIPT @PatientId, @PatientMasterVisitId, @DateStartedIpt, @Outcome, @OutcomeDate, @userId, @ReasonsForDiscontinuation, @Success OUT 

				IF @success = 1 
					UPDATE IQCareIPTLineList SET Updated = 1, DateUpdated = GETDATE() WHERE PatientId = @FullcccNumber
				ELSE
					UPDATE IQCareIPTLineList SET Updated = 9, DateUpdated = GETDATE() WHERE PatientId = @FullcccNumber
								
			END
			ELSE
			BEGIN
				UPDATE IQCareIPTLineList SET Updated = 4, DateUpdated = getdate() WHERE PatientId = @fullcccNumber				
			END

			--print @FullCCCNUmber
			DELETE FROM #tmpUpdateIPT WHERE FullCccNumber = @FullcccNumber 
			SELECT @FullcccNumber = min(FullCCCNumber) FROM #tmpUpdateIPT
			SELECT 
				@sex = (CASE WHEN sex = 'M' THEN 51 ELSE 52 END), @cccNumber = CCCNumber, @fullCCCNumber = FullCCCNumber, @firstName = (SUBSTRING([PatientName],0,CHARINDEX(' ', [PatientName]))),  
				@DateStartedIpt = DateStartedIpt,@Outcomestring = Outcome, @OutcomeDate = OutcomeDate, @ReasonsForDiscontinuation = ReasonsForDiscontinuation
			FROM #tmpUpdateIPT  WHERE FullcccNumber = @FullcccNumber

END
go

exec pr_CloseDecryptedSession
go