ALTER PROCEDURE get_mch_data_template(@startDate as DATE, @endDate as DATE) AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#tmpPeriod') IS NOT NULL
		DROP TABLE #tmpPeriod
	

	IF OBJECT_ID('tempdb..#tmpDataTemplate') IS NOT NULL
		DROP TABLE #tmpDataTemplate
	

	IF EXISTS(SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmpDataTemplate'))
		DROP TABLE tmpDataTemplate
	

	IF OBJECT_ID('tempdb..#tmpVisits') IS NOT NULL
		DROP TABLE #tmpVisits
	

	IF OBJECT_ID('tempdb..#tmpPatients') IS NOT NULL
		DROP TABLE #tmpPatients
	

	IF OBJECT_ID('tempdb..#tmpRegimens') IS NOT NULL
		DROP TABLE #tmpRegimens
	

	IF OBJECT_ID('tempdb..#tmpTCA') IS NOT NULL
		DROP TABLE #tmpTCA
	
	exec pr_OpenDecryptedSession

	-- BEGIN: Patients Master TMP table
	SELECT id AS PatientId, EnrollmentNumber AS CCCNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName,DateOfBirth as DOB, DATEDIFF(M, DateOfBirth, @endDate)/12 AS Age, RegistrationDate AS EnrollmentDate 
	INTO #tmpPatients
	FROM gcPatientView WHERE EnrollmentDate <= @endDate; -- AND ptn_pk =50; 

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
			SELECT PatientId, VisitDate, PatientMasterVisitId, ProviderNames, MCHNumber,TINumber, CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period, ROW_NUMBER() OVER(PARTITION BY PatientId, YEAR(VisitDate), MONTH(VisitDate) ORDER BY VisitDate DESC) as RowNum FROM all_visits_cte
		) v WHERE RowNum = 1
	)

	SELECT v.PatientId,v.VisitDate, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as PatientMasterVisitId,v.MCHNumber,v.TINumber,v.Period,p.CCCNumber,p.DOB,p.Age,p.PatientName,p.EnrollmentDate,v.ProviderNames as LastProviders
	INTO #tmpVisits
	FROM unique_visits_cte v
	INNER JOIN #tmpPatients p ON p.PatientId = v.PatientId
	--END: Prepare the visits staging table #tmpVisits


	-- BEGIN: populate periods table
	SELECT Year,Month, CONCAT(Year,RIGHT(CONCAT(0,Month),2)) AS Period 
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
	SET @strTemplateSql = 'CREATE TABLE tmpDataTemplate (PatientId INT PRIMARY KEY, CCCNumber NVARCHAR(15), MCHNumber NVARCHAR(15), TINumber NVARCHAR(15), PatientName NVARCHAR(50), DOB DATE, Age INT,EnrollmentDate DATE,LastProviders NVARCHAR(100)'

	DECLARE @period as INT 
	SELECT @period = MIN(Period) FROM #tmpPeriod;
	WHILE (@period IS NOT NULL)
	BEGIN
		SET @strTemplateSql =  CONCAT(@strTemplateSql, CONCAT(',[',@period,'-date] DATE, [',@period,'-regimen] NVARCHAR(15), [',@period,'-pres-duration] INT, [',@period,'-tca] DATE'))
		DELETE FROM #tmpPeriod WHERE period = @period
		SELECT @period = MIN(Period) FROM #tmpPeriod;
	END
	SET @strTemplateSql = CONCAT(@strTemplateSql,')')
	EXEC sp_executesql @strTemplateSql;
	-- END create the template table that will be fed with our data

	-- BEGIN: Populating the data Template table with Visits Data
	DECLARE @PatientMasterVisitId AS INT
	SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpVisits
	WHILE @PatientMasterVisitId IS NOT NULL
	BEGIN
		DECLARE @PatientId INT, @CCCNumber NVARCHAR(15),@MCHNumber NVARCHAR(15),@TINumber NVARCHAR(15), @PatientName NVARCHAR(50), @DOB DATE, @Age INT, @CurrentPeriod INT, @VisitDate DATE, @EnrollmentDate DATE, @lastProviders NVARCHAR(100)
		SELECT @PatientId =PatientId, @CCCNumber = CCCNumber,@MCHNumber=MCHNumber,@TINumber=TINumber,@PatientName=PatientName,@DOB=DOB,@Age=Age,@CurrentPeriod=Period, @VisitDate=VisitDate, @EnrollmentDate=EnrollmentDate,@lastProviders=LastProviders FROM #tmpVisits WHERE PatientMasterVisitId = @PatientMasterVisitId
	
		IF NOT EXISTS(SELECT * FROM [tmpDataTemplate] WHERE PatientId = @PatientId)
		BEGIN
			INSERT INTO [tmpDataTemplate]([PatientId],[CCCNumber],[MCHNumber],[TINumber],[PatientName],[DOB],[Age],[EnrollmentDate],[LastProviders])
			VALUES (@PatientId,@CCCNumber,@MCHNumber,@TINumber,@PatientName,@DOB,@Age,@EnrollmentDate,@lastProviders)
		END
	
		DECLARE @strUpdateTemplateTblSQL NVARCHAR(MAX)
		SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET [', CONCAT(@CurrentPeriod,'-date]'), '=''', @VisitDate,''' WHERE PatientId=', @PatientId)
		EXEC sp_executesql @strUpdateTemplateTblSQL

		DELETE FROM #tmpVisits WHERE PatientMasterVisitId = @PatientMasterVisitId
		SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpVisits
	END;
	-- BEGIN: Populating the data Template table with Visits Data

	--BEGIN: Prepare the Regimens staging table #tmpRegimens
	WITH all_art_cte AS (
			SELECT PatientMasterVisitId,RegimenId, t.PatientId,t.RegimenLine,REPLACE(SUBSTRING(Regimen,CHARINDEX('(',Regimen)+1,LEN(Regimen) - CHARINDEX('(',Regimen) - 1),' + ','/') AS Regimen, CAST(t.RegimenStartDate AS DATE) as RegimenDate,CONCAT(YEAR(RegimenStartDate),RIGHT(CONCAT(0,MONTH(RegimenStartDate)),2)) AS Period, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,ptn_pharmacy_pk FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate >= @startDate AND t.RegimenStartDate <= @endDate -- AND ptn_pk =50
	),

	pres_duration_cte AS (
		SELECT PatientId, Duration AS PrescriptionDuration, PatientMasterVisitId, VisitID,od.ptn_pharmacy_pk 
		FROM dtl_PatientPharmacyOrder dt 
		INNER JOIN ord_PatientPharmacyOrder od ON dt.ptn_pharmacy_pk = od.ptn_pharmacy_pk
	),

	unique_art_cte AS (
		SELECT PatientId,RegimenDate,Regimen,PatientMasterVisitId,PrescriptionDuration,Period,RowNum FROM (
			SELECT art.PatientId, art.RegimenDate, art.Regimen,Period,art.PatientMasterVisitId,pr.PrescriptionDuration, ROW_NUMBER() OVER(PARTITION BY art.PatientId, Period ORDER BY RegimenDate DESC) as RowNum FROM all_art_cte art
			INNER JOIN pres_duration_cte pr ON pr.ptn_pharmacy_pk = art.ptn_pharmacy_pk AND pr.PatientId = art.PatientId
		) v  WHERE RowNum = 1
	)

	SELECT v.PatientId,v.RegimenDate, v.Regimen, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as PatientMasterVisitId,v.PrescriptionDuration,v.Period
	INTO #tmpRegimens
	FROM unique_art_cte v;

	--END: Prepare the visits staging table #tmpVisits

	--BEGIN: Prepare the TCAs staging table #tmpTCA
	WITH all_tca_cte AS (
		SELECT PatientId,AppointmentDate,Visitdate,CONCAT(YEAR(VisitDate),RIGHT(CONCAT(0,MONTH(VisitDate)),2)) AS Period,ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as PatientMasterVisitId FROM (
			SELECT p.PatientId, CAST(AppointmentDate AS DATE) as AppointmentDate, CAST(VisitDate as DATE) as Visitdate FROM PatientAppointment p INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id 
			INNER JOIN LookupItem l ON L.Id = StatusId
			WHERE (VisitDate <= @endDate AND VisitDate >= @startDate)
			UNION
			SELECT p.id as PatientId,CAST(AppDate AS DATE) as AppointmentDate,CAST(o.VisitDate AS DATE) as VisitDate FROM dtl_PatientAppointment a INNER JOIN Patient p ON a.Ptn_pk = p.ptn_pk INNER JOIN ord_Visit o  ON o.Visit_Id = a.Visit_pk
			WHERE VisitDate <= @endDate AND VisitDate >= @startDate
		) t
	),

	unique_tca_cte AS (
		SELECT PatientId,Visitdate,AppointmentDate,PatientMasterVisitId,Period,RowNum FROM (
			SELECT tca.PatientId, tca.Visitdate,tca.AppointmentDate ,Period, tca.PatientMasterVisitId, ROW_NUMBER() OVER(PARTITION BY tca.PatientId, Period ORDER BY VisitDate DESC) as RowNum FROM all_tca_cte tca		
		) v  WHERE RowNum = 1
	)


	SELECT v.PatientId,v.VisitDate, v.AppointmentDate, v.PatientMasterVisitId,v.Period
	INTO #tmpTCA
	FROM unique_tca_cte v
	--END: Prepare the visits staging table #tmpVisits


	-- BEGIN: Update the data template table with Regimen data
	SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpRegimens
	WHILE @PatientMasterVisitId IS NOT NULL
	BEGIN
		DECLARE @Regimen NVARCHAR(15),@RegimenDate AS DATE, @PrescriptionDuration INT
		SELECT @PatientId =PatientId, @CurrentPeriod=Period,@Regimen=Regimen, @RegimenDate=RegimenDate, @PrescriptionDuration =PrescriptionDuration FROM #tmpRegimens WHERE PatientMasterVisitId = @PatientMasterVisitId
	
		IF EXISTS(SELECT * FROM [tmpDataTemplate] WHERE PatientId = @PatientId)
		BEGIN
			SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET [', @CurrentPeriod,'-regimen]=''', @Regimen,''',[', @CurrentPeriod ,'-pres-duration]=', @PrescriptionDuration ,' WHERE PatientId=', @PatientId)
			EXEC sp_executesql @strUpdateTemplateTblSQL
		END

		DELETE FROM #tmpRegimens WHERE PatientMasterVisitId = @PatientMasterVisitId
		SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpRegimens
	END;
	-- END: Update the data template table with Regimen data

	-- BEGIN: Update the data template table with TCA data
	SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpTCA
	WHILE @PatientMasterVisitId IS NOT NULL
	BEGIN
		DECLARE @AppointmentDate AS DATE
		SELECT @PatientId =PatientId, @CurrentPeriod=Period,@VisitDate=VisitDate, @AppointmentDate=AppointmentDate FROM #tmpTCA WHERE PatientMasterVisitId = @PatientMasterVisitId
	
		IF EXISTS(SELECT * FROM [tmpDataTemplate] WHERE PatientId = @PatientId)
		BEGIN
			SET @strUpdateTemplateTblSQL = CONCAT('UPDATE tmpDataTemplate SET [', @CurrentPeriod,'-tca]=''', @AppointmentDate,''' WHERE PatientId=', @PatientId)
			EXEC sp_executesql @strUpdateTemplateTblSQL
		END

		DELETE FROM #tmpTCA WHERE PatientMasterVisitId = @PatientMasterVisitId
		SELECT @PatientMasterVisitId = MIN(PatientMasterVisitId) FROM #tmpTCA
	END;
	-- END: Update the data template table with TCA data

	SELECT * FROM tmpDataTemplate

	--BEGIN: Housekeeping
	DROP TABLE #tmpPeriod
	DROP TABLE #tmpVisits
	DROP TABLE #tmpPatients
	DROP TABLE #tmpTCA
	DROP TABLE tmpDataTemplate

	exec pr_CloseDecryptedSession

	--END: Housekeeping
END 