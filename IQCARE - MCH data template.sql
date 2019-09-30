--DECLARE @startDate AS DATE = '2015-01-01', @endDate AS DATE = '2018-12-31'
--exec get_mch_data_template @startDate, @endDate
--return
-- This process exports data into a template table that contains all visits, precriptions, and TCA dates given for each patient

-- Get all the periods from patientvisitmaster and visits table and post them to a staging table
-- Get all visits for each client for each month.
-- Get all dispensed drugs(date and regimen) for each client for each month.
-- Get all TCA dates

USE IQCARE_CPAD
GO

SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#tmpPeriod') IS NOT NULL
		DROP TABLE #tmpPeriod
	

	IF OBJECT_ID('tempdb..#tmpDataTemplate') IS NOT NULL
		DROP TABLE #tmpDataTemplate
	

	IF EXISTS(SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmpDataTemplate'))
		DROP TABLE tmpDataTemplate
	
	IF EXISTS(SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmpMCHDataCleaning'))
		DROP TABLE tmpMCHDataCleaning
	
	IF OBJECT_ID('tempdb..#tmpVisits') IS NOT NULL
		DROP TABLE #tmpVisits
	

	IF OBJECT_ID('tempdb..#tmpPatients') IS NOT NULL
		DROP TABLE #tmpPatients
	

	IF OBJECT_ID('tempdb..#tmpRegimens') IS NOT NULL
		DROP TABLE #tmpRegimens
	

	IF OBJECT_ID('tempdb..#tmpTCA') IS NOT NULL
		DROP TABLE #tmpTCA

	IF OBJECT_ID('tempdb..#tmpVitals') IS NOT NULL
		DROP TABLE #tmpVitals

	IF OBJECT_ID('tempdb..#tmpCD4') IS NOT NULL
		DROP TABLE #tmpCD4

	IF OBJECT_ID('tempdb..#tmpVLs') IS NOT NULL
		DROP TABLE #tmpVLs

	IF OBJECT_ID('tempdb..#tmpAllData') IS NOT NULL
		DROP TABLE #tmpAllData

		
DECLARE @endDate as DATE = '2019-03-26'
DECLARE @startDate as DATE = '2015-01-01'

exec pr_OpenDecryptedSession

-- BEGIN: Patients Master TMP table
SELECT id AS PatientId, EnrollmentNumber AS CCCNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName,DateOfBirth as DOB, DATEDIFF(M, DateOfBirth, @endDate)/12 AS Age, RegistrationDate AS EnrollmentDate 
INTO #tmpPatients
FROM gcPatientView WHERE EnrollmentDate <= @endDate; --  AND id = 7091; 

-- END: Patients Master TMP Table

--BEGIN: Prepare the visits staging table #tmpVisits
--Providers 
-- Aggrey Omunyolo,Susan Onywera,Diana Oketch,Sharon, Nancy Odhiambo
WITH providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
),

mch_cte AS (
	select PatientId,MCHNumber FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber FROM mst_Patient M INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk WHERE LEN(MCHID) > 0 -- IS NOT NULL
	) ti WHERE rowNUm = 1
),

ti_cte AS (
	select PatientId,TiNumber FROM (                                                
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY PatientId) AS rowNUm, PatientID, IdentifierValue as TINumber FROM PatientIdentifier WHERE IdentifierTypeId = 17
	) ti WHERE rowNUm = 1
),

all_visits_cte AS (
	SELECT DISTINCT PatientId,VisitDate,PatientMasterVisitId,
	ProviderNames = '',
--	ProviderNames = STUFF((SELECT DISTINCT ','+p.ProviderName FROM PatientEncounter e INNER JOIN providers_cte p ON p.UserID = e.CreatedBy WHERE e.PatientMasterVisitId=visits.PatientMasterVisitId FOR XML PATH('')) , 1 , 1 , '' ),		
	MCHNumber,TINumber FROM (
		SELECT v.PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID, mch.MCHNumber,Ti.TINumber FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, e.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate) AND VisitDate >= @startDate AND VisitDate < @endDate
			UNION
			SELECT p.PatientId,CAST(VisitDate AS DATE) as VisitDate,p.PatientMasterVisitId, o.UserID as LastProvider from ord_Visit o INNER JOIN ord_PatientPharmacyOrder p ON o.Ptn_pk = p.ptn_pk AND o.Visit_Id = p.VisitID
			WHERE VisitDate >= @startDate AND VisitDate <= @endDate
			UNION
			SELECT p.PatientId,CAST(VisitDate AS DATE) as VisitDate,p.PatientMasterVisitId, o.UserID as LastProvider from ord_Visit o INNER JOIN ord_LabOrder p ON o.Ptn_pk = p.ptn_pk AND o.Visit_Id = p.VisitId
			WHERE VisitDate >= @startDate AND VisitDate <= @endDate
		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
		INNER JOIN mch_cte mch ON mch.PatientID = v.PatientId
		LEFT JOIN ti_cte ti ON ti.PatientID = v.PatientId
--		WHERE v.ProviderId IN (14,20,33,132,135)
	) visits -- WHERE PatientId = 19
),

period_cte AS (
	SELECT DISTINCT Year(VisitDate) as Year,Month(VisitDate) as Month, CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period 
	FROM all_visits_cte 
),

unique_visits_cte AS (
	SELECT * FROM (
		SELECT PatientId, VisitDate, ProviderNames, MCHNumber,TINumber, CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period, ROW_NUMBER() OVER(PARTITION BY PatientId, YEAR(VisitDate), MONTH(VisitDate) ORDER BY VisitDate DESC) as RowNum FROM all_visits_cte
	) v WHERE RowNum = 1
)

SELECT v.PatientId,v.VisitDate, v.MCHNumber,v.TINumber,v.Period,p.CCCNumber,p.DOB,p.Age,p.PatientName,p.EnrollmentDate,v.ProviderNames as LastProviders
INTO #tmpVisits
FROM unique_visits_cte v
INNER JOIN #tmpPatients p ON p.PatientId = v.PatientId;
--END: Prepare the visits staging table #tmpVisits


--BEGIN: Prepare the Regimens staging table #tmpRegimens
WITH all_art_cte AS (
		SELECT PatientMasterVisitId,RegimenId, t.PatientId,t.RegimenLine,REPLACE(SUBSTRING(Regimen,CHARINDEX('(',Regimen)+1,LEN(Regimen) - CHARINDEX('(',Regimen) - 1),' + ','/') AS Regimen, CAST(t.RegimenStartDate AS DATE) as RegimenDate,CONCAT(YEAR(RegimenStartDate),RIGHT(CONCAT(0,MONTH(RegimenStartDate)),2)) AS Period, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,ptn_pharmacy_pk FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate >= @startDate AND t.RegimenStartDate <= @endDate -- AND ptn_pk =50
),

pres_duration_cte AS (
	SELECT PatientId, Duration AS PrescriptionDuration, VisitID,od.ptn_pharmacy_pk 
	FROM dtl_PatientPharmacyOrder dt 
	INNER JOIN ord_PatientPharmacyOrder od ON dt.ptn_pharmacy_pk = od.ptn_pharmacy_pk
),

unique_art_cte AS (
	SELECT PatientId,RegimenDate,Regimen,PatientMasterVisitId,PrescriptionDuration,Period,RowNum FROM (
		SELECT art.PatientId, art.RegimenDate, art.Regimen,Period,art.PatientMasterVisitId,pr.PrescriptionDuration, ROW_NUMBER() OVER(PARTITION BY art.PatientId, Period ORDER BY RegimenDate DESC) as RowNum FROM all_art_cte art
		INNER JOIN pres_duration_cte pr ON pr.ptn_pharmacy_pk = art.ptn_pharmacy_pk AND pr.PatientId = art.PatientId
	) v  WHERE RowNum = 1
)

SELECT a.PatientId,a.RegimenDate, a.Regimen, a.PrescriptionDuration,v.Period
INTO #tmpRegimens
FROM unique_art_cte a
INNER JOIN #tmpVisits v ON a.PatientId=v.PatientId AND a.Period = v.Period;
--END: Prepare the Regimens staging table #tmpRegimens

--BEGIN: Prepare the TCAs staging table #tmpTCA
WITH all_tca_cte AS (
	SELECT PatientId,AppointmentDate,Visitdate,CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period FROM (
		SELECT p.PatientId, CAST(AppointmentDate AS DATE) as AppointmentDate, CAST(VisitDate as DATE) as Visitdate FROM PatientAppointment p INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id 
		INNER JOIN LookupItem l ON L.Id = StatusId
		WHERE (VisitDate <= @endDate AND VisitDate >= @startDate)
		UNION
		SELECT p.id as PatientId,CAST(AppDate AS DATE) as AppointmentDate,CAST(o.VisitDate AS DATE) as VisitDate FROM dtl_PatientAppointment a INNER JOIN Patient p ON a.Ptn_pk = p.ptn_pk INNER JOIN ord_Visit o  ON o.Visit_Id = a.Visit_pk
		WHERE VisitDate <= @endDate AND VisitDate >= @startDate
	) t
),

unique_tca_cte AS (
	SELECT PatientId,Visitdate,AppointmentDate,Period,RowNum FROM (
		SELECT tca.PatientId, tca.Visitdate,tca.AppointmentDate ,Period, ROW_NUMBER() OVER(PARTITION BY tca.PatientId, Period ORDER BY VisitDate DESC) as RowNum FROM all_tca_cte tca		
	) v  WHERE RowNum = 1
)


SELECT t.PatientId, t.VisitDate, t.AppointmentDate,v.Period
INTO #tmpTCA
FROM unique_tca_cte t
INNER JOIN #tmpVisits v ON t.PatientId = v.PatientId AND t.Period = v.Period;
--END: Prepare the TCA staging table #tmpTCA

--BEGIN: Prepare the Vitals staging table #tmpVitals
WITH all_vitals_cte AS (
	SELECT PatientId, Weight,Height,VisitDate,CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period FROM ( 
		SELECT PatientId, vi.Weight, vi.Height, VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientId, CAST (vi.VisitDate AS DATE) ORDER BY vi.VisitDate) as RowNum FROM (
			SELECT vi.PatientId, CAST (vi.CreateDate AS DATE) as VisitDate,vi.Weight,vi.Height FROM PatientVitals vi WHERE CreateDate >= @startDate AND CreateDate <= @endDate
			UNION
			SELECT p.id AS PatientId, CAST(vi.CreateDate AS DATE) as VisitDate,vi.Weight,vi.Height FROM dtl_PatientVitals vi  INNER JOIN patient p on p.ptn_pk = vi.Ptn_pk  WHERE vi.CreateDate >= @startDate AND vi.CreateDate <= @endDate
		) vi		 
	) vit WHERE rowNUm = 1
),

unique_vitals_cte AS (
	SELECT PatientId,Visitdate,Height,Weight,Period FROM (
		SELECT vit.PatientId, vit.Visitdate,vit.Height,vit.Weight ,Period, ROW_NUMBER() OVER(PARTITION BY vit.PatientId, Period ORDER BY VisitDate DESC) as RowNum FROM all_vitals_cte vit		
	) v  WHERE RowNum = 1
)


SELECT t.PatientId, t.VisitDate, t.Height,t.Weight,v.Period
INTO #tmpVitals
FROM unique_vitals_cte t
INNER JOIN #tmpVisits v ON t.PatientId = v.PatientId AND t.Period = v.Period;
--END: Prepare the Vitals staging table #tmpVitals

--BEGIN: Prepare the VL staging table #tmpVitals
WITH all_VLs_cte AS (
	SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as VlDate, CASE WHEN tr.Undetectable = 1  OR ResultTexts LIKE '%< LDL%' then 0 else ResultValues END  as VLValue, CONCAT(YEAR(SampleDate),RIGHT(CONCAT(0,MONTH(SampleDate)),2)) AS Period
	FROM            dbo.PatientLabTracker t
	INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
	WHERE        (Results = 'Complete')
	AND         (t.LabTestId = 3) AND SAmpleDate <= @endDate 	AND SampleDate >= @startDate),

unique_VLs_cte AS (
	SELECT PatientId,VlDate,VLValue,Period FROM (
		SELECT vl.PatientId, vl.VLdate,vl.VLValue ,Period, ROW_NUMBER() OVER(PARTITION BY vl.PatientId, Period ORDER BY vldate DESC) as RowNum FROM all_VLs_cte vl		
	) v  WHERE RowNum = 1
)


SELECT t.PatientId, t.VlDate, t.VLValue,v.Period
INTO #tmpVLs
FROM unique_VLs_cte t
INNER JOIN #tmpVisits v ON t.PatientId = v.PatientId AND t.Period = v.Period;
--END: Prepare the VL staging table #tmpVLs

--BEGIN: Prepare the CD4 staging table #tmpCD4
WITH all_CD4_cte AS (
	SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as cd4Date,ResultValues  as CD4Value, CONCAT(YEAR(SampleDate),RIGHT(CONCAT(0,MONTH(SampleDate)),2)) AS Period
	FROM            dbo.PatientLabTracker t
	INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
	WHERE        (Results = 'Complete')
	AND         (t.LabTestId = 1) AND SAmpleDate <= @endDate 	AND SampleDate >= @startDate),

unique_CD4_cte AS (
	SELECT PatientId,CD4Date,CD4Value,Period FROM (
		SELECT cd4.PatientId, cd4.CD4Value, CD4.cd4Date ,Period, ROW_NUMBER() OVER(PARTITION BY cd4.PatientId, Period ORDER BY cd4Date DESC) as RowNum FROM all_CD4_cte cd4	
	) v  WHERE RowNum = 1
)

SELECT t.PatientId, t.cd4Date, t.Cd4Value,v.Period
INTO #tmpCD4
FROM unique_CD4_cte t
INNER JOIN #tmpVisits v ON t.PatientId = v.PatientId AND t.Period = v.Period
--END: Prepare the CD4 staging table #tmpCD4

-- BEGIN: populate periods table
SELECT ROW_NUMBER() OVER (ORDER BY Year DESC, Month ASC) as Ord, Year,Month, CONCAT(Year,RIGHT(CONCAT(0,Month),2)) AS Period 
INTO
#tmpPeriod
FROM (
	SELECT DISTINCT YEAR(VisitDate) as Year, MONTH(VisitDate) as Month FROM PatientMasterVisit WHERE  VisitDate BETWEEN  @startDate AND @endDate -- ORDeR BY YEAR(VisitDate) DESC, MONTH(VisitDate)
	UNION
	SELECT  DISTINCT YEAR(VisitDate) as Year, MONTH(VisitDate) as Month FROM ord_Visit WHERE VisitDate BETWEEN @startDate AND @endDate
) p ORDER BY Period DESC;
-- End Populate periods table

-- BEGIN: create the data template table that will be fed with our data
DECLARE @strTemplateSql AS NVARCHAR(MAX) = ''
SET @strTemplateSql = 'CREATE TABLE tmpDataTemplate (PatientId INT PRIMARY KEY, CCCNumber NVARCHAR(15), MCHNumber NVARCHAR(15), TINumber NVARCHAR(15), PatientName NVARCHAR(50), DOB DATE, Age INT,EnrollmentDate DATE,LastProviders NVARCHAR(100),LastVisitDate DATE '

DECLARE @ord as INT 
DECLARE @Period as INT 
SELECT @ord = MIN(Ord) FROM #tmpPeriod;
WHILE (@ord IS NOT NULL)
BEGIN
	SELECT @Period=Period FROM  #tmpPeriod WHERE Ord = @Ord;
	SET @strTemplateSql =  CONCAT(@strTemplateSql, CONCAT(',[',@period,'-date] DATE, [',@period,'-height] INT, [',@period,'-weight] INT, [',@period,'-cd4] INT, [',@period,'-vl] INT, [',@period,'-regimen] NVARCHAR(50), [',@period,'-pres-duration] INT, [',@period,'-tca] DATE'))
	DELETE FROM #tmpPeriod WHERE Ord = @ord
	SELECT @ord = MIN(Ord) FROM #tmpPeriod;
END
SET @strTemplateSql = CONCAT(@strTemplateSql,')')
EXEC sp_executesql @strTemplateSql;
-- END create the template table that will be fed with our data

-- BEGIN: Populate finalstaging table
SELECT 
ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as PatientMasterVisitId,
v.*,vit.Height,vit.Weight, c.CD4Value as CD4, vl.VLValue as VL, r.Regimen,r.RegimenDate,r.PrescriptionDuration, t.AppointmentDate
INTO #tmpAllData
FROM #tmpVisits v 
LEFT JOIN #tmpRegimens r ON v.PatientId = r.PatientId AND r.Period = v.Period
LEFT JOIN #tmpTCA t ON v.PatientId = t.PatientId AND v.Period = t.Period
LEFT JOIN #tmpVitals vit ON vit.PatientId = t.PatientId AND vit.Period = t.Period
LEFT JOIN #tmpCD4 c ON c.PatientId = v.PatientId AND c.Period = v.Period
LEFT JOIN #tmpVLs vl ON vl.PatientId = v.PatientId AND vl.Period = v.Period

-- END: Populate final staging table

-- BEGIN: Populating the data Template table
DECLARE @PatientMasterVisitId AS INT
SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpAllData
WHILE @PatientMasterVisitId IS NOT NULL
BEGIN
	DECLARE @PatientId INT, @CCCNumber NVARCHAR(15),@MCHNumber NVARCHAR(15),@TINumber NVARCHAR(15), @PatientName NVARCHAR(50), @DOB DATE, @Age INT, @CurrentPeriod INT, @VisitDate DATE, @EnrollmentDate DATE, @lastProviders NVARCHAR(100),@Regimen NVARCHAR(50),@AppointmentDate DATE, @PrescriptionDuration INT, @Height INT, @Weight INT, @VL INT, @CD4 INT
	SELECT @PatientId =PatientId, @CCCNumber = CCCNumber,@MCHNumber=MCHNumber,@TINumber=TINumber,@PatientName=PatientName,@DOB=DOB,@Age=Age,@CurrentPeriod=Period, @VisitDate=VisitDate, @EnrollmentDate=EnrollmentDate,@lastProviders=LastProviders, @Regimen=Regimen,@AppointmentDate=AppointmentDate,@PrescriptionDuration=PrescriptionDuration, @Height= Height, @Weight=Weight, @VL=VL, @CD4=CD4 FROM #tmpAllData WHERE PatientMasterVisitId = @PatientMasterVisitId
	
	IF NOT EXISTS(SELECT * FROM [tmpDataTemplate] WHERE PatientId = @PatientId)
	BEGIN
		INSERT INTO [tmpDataTemplate]([PatientId],[CCCNumber],[MCHNumber],[TINumber],[PatientName],[DOB],[Age],[EnrollmentDate],[LastProviders])
		VALUES (@PatientId,@CCCNumber,@MCHNumber,@TINumber,@PatientName,@DOB,@Age,@EnrollmentDate,@lastProviders)
	END
	
	DECLARE @strUpdateTemplateTblSQL NVARCHAR(MAX)
	IF @PrescriptionDuration IS NOT NULL AND @AppointmentDate IS NOT NULL AND @Regimen IS NOT NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-date]'), '=''', @VisitDate,''', 
			[', @CurrentPeriod,'-regimen]=''', @Regimen,''',[', @CurrentPeriod ,'-pres-duration]=', @PrescriptionDuration , ', 
			[', @CurrentPeriod,'-tca]=''', @AppointmentDate,'''
			WHERE PatientId=', @PatientId)
	IF @PrescriptionDuration IS NOT NULL AND @Regimen IS NOT NULL AND @AppointmentDate IS NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-date]'), '=''', @VisitDate,''', 
			[', @CurrentPeriod,'-regimen]=''', @Regimen,''',[', @CurrentPeriod ,'-pres-duration]=', @PrescriptionDuration , ' 
			WHERE PatientId=', @PatientId)
	IF @AppointmentDate IS NOT NULL AND (@Regimen IS NULL OR @PrescriptionDuration IS NULL)
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-date]'), '=''', @VisitDate,''', 
			[', @CurrentPeriod,'-tca]=''', @AppointmentDate,'''
			WHERE PatientId=', @PatientId)
	EXEC sp_executesql @strUpdateTemplateTblSQL

	IF @Height IS NOT NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-height]'), '=', @Height,' 
			WHERE PatientId=', @PatientId)
	EXEC sp_executesql @strUpdateTemplateTblSQL

	IF @Weight IS NOT NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-weight]'), '=', @Weight,' 
			WHERE PatientId=', @PatientId)
	EXEC sp_executesql @strUpdateTemplateTblSQL

	IF @CD4 IS NOT NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-cd4]'), '=', @CD4,' 
			WHERE PatientId=', @PatientId)
	EXEC sp_executesql @strUpdateTemplateTblSQL

	IF @VL IS NOT NULL
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET 
			[', CONCAT(@CurrentPeriod,'-vl]'), '=', @VL,' 
			WHERE PatientId=', @PatientId)
	EXEC sp_executesql @strUpdateTemplateTblSQL

	DELETE FROM #tmpAllData WHERE PatientMasterVisitId = @PatientMasterVisitId
	SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpAllData
END;
-- END: Populating the data Template table 

SELECT * FROM tmpDataTemplate
-- SELECT * FROM #tmpAllData
--BEGIN: Housekeeping
DROP TABLE #tmpPeriod
DROP TABLE #tmpVisits
DROP TABLE #tmpPatients
DROP TABLE #tmpTCA
--DROP TABLE tmpDataTemplate

exec pr_CloseDecryptedSession

--END: Housekeeping
