set rowcount 0

DECLARE @ptnPk as INT
DECLARE @locationId as INT = 754
DECLARE @VisitDate AS DATE
DECLARE @CD4 as INT
DECLARE @WHOStage as INT
DECLARE @Height as INT = NULL
DECLARE @Weight as INT = NULL
DECLARE @BaselineId as INT
DECLARE @visitType as INT = 6
DECLARE @userId as INT = 1
DECLARE @typeOfVisit as INT = 70
DECLARE @moduleId as INT = 203
DECLARE @createDate as DATE = getdate()
DECLARE @patientId as INT
DECLARE @visitId as INT
DECLARE @patientMasterVisitId as INT
DECLARE @labOrderId as int
DECLARE @labTestId as int = 3
DECLARE @resultValues as int
DECLARE @labOrderTestId as int
DECLARE @encounterTypeId as int = 1503
DECLARE @serviceAreaId as int = 205
DECLARE @resultDate as date

DECLARE @id as int

declare @sex AS nvarchar(6)
declare @fullcccNumber AS nvarchar(15)
declare @firstName AS nvarchar(max)
declare @rc AS int

BEGIN TRY 
	DROP table #tmpBaseline
END TRY
BEGIN CATCH
END CATCH

SELECT
Id, [CCC Number] AS PatientId,[WHO Stage At Enrollment] as WHOStage, [CD4 Count at Enrollment] as CD4	
INTO #tmpBaseline
FROM [dbo].IQCareBaselineWHOCD4 d WHERE Updated = 0 AND [WHO Stage At Enrollment] IS NOT NULL
--AND PatientId IN ('13939-00795') --IS NOT NULL

select * from #tmpBaseline
SELECT @id = min(id) FROM #tmpBaseline

set rowcount 0

WHILE @id IS NOT NULL
BEGIN				

		-- Get Visit Date		
		SELECT @VisitDate=MIN(VisitDate), @patientId = @id FROM PatientMasterVisit WHERE PatientId = @id AND VisitDate IS NOT NULL
		exec sp_getVisit @VisitDate, @id, @PatientMasterVisitId OUTPUT, @VisitId OUTPUT, @UserId OUTPUT
		
		SELECT @CD4 = CD4, @WHOStage = (CASE WHOStage WHEN  1 THEN 129 WHEN 2 THEN 130 WHEN 3 THEN 131 WHEN 4 THEN 132 END) FROM #tmpBaseline WHERE id = @id

		SELECT @Weight=Weight, @Height=Height FROM PatientVitals WHERE ID = (SELECT MIN(ID) FROM PatientVitals WHERE PatientId = @patientId)
		
		if @@ROWCOUNT = 0
			SELECT @weight=1, @height=1
	
		SELECT 
			top 1 @BaselineId = Id
		FROM PatientBaselineAssessment
		WHERE 
			PatientId = @Id
					
		if	@@ROWCOUNT = 0 
			BEGIN
				INSERT [dbo].PatientBaselineAssessment
				([PatientMasterVisitId], [PatientId], WHOStage, CD4Count, [CreateDate], [CreatedBy], [DeleteFlag], HBVInfected, Pregnant, TBinfected, BreastFeeding, MUAC, Height, Weight)
				VALUES 
				(@PatientMasterVisitId, @Id, @WHOStage, @CD4, getdate(), 1, 0, 0, 0, 0, 0, NULL, @Height, @Weight)
			END
		ELSE
			BEGIN
				UPDATE PatientBaselineAssessment SET WHOStage = @WHOStage, CD4Count = @CD4 WHERE PatientId = @Id
			END

		UPDATE IQCareBaselineWHOCD4 SET Updated = 1, DateUpdated = GETDATE() WHERE ID = @id

		DELETE FROM #tmpBaseline WHERE Id = @Id 
		SELECT @Id = min(Id) FROM #tmpBaseline
END
