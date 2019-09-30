-- =============================================
-- Author:		John Macharia
-- Create date: 13th May 2018
-- Description:	Differentiated Care Parameters
-- =============================================
ALTER PROCEDURE [dbo].[sp_DifferentiatedCareParameters] 
	-- Add the parameters for the stored procedure here
	@PatientId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @ptn_pk int = (select ptn_pk from patient where id = @PatientId)

    -- Age
	Select datediff(year, DateOfBirth, getdate()) Age from Patient where Id = @PatientId

	-- BMI
	select top 1 BMI from patientvitals where PatientId = @PatientId order by VisitDate desc

	-- Viral Load
	DECLARE @CurrentRegimenStart AS DATE;
	WITH all_treatmenttracker_cte AS (
		SELECT t.id, t.PatientMasterVisitId,  t.PatientId, t.Regimen, t.RegimenId, t.RegimenDate, t.Line AS regimenLine, t.TLE400
		FROM (SELECT t.Id, t.PatientMasterVisitId, t.RegimenId, Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenStartDate
			DESC) AS rowNum, t.PatientId, t.RegimenLine, t.Regimen, t.RegimenStartDate AS RegimenDate,
			CASE WHEN t.RegimenLine LIKE '%First%' THEN '1'
			  WHEN t.RegimenLine LIKE '%Second%' THEN '2'
			  WHEN t.RegimenLine LIKE '%third%' THEN 3 ELSE NULL END AS Line,
			TLE400 = (
				SELECT CASE WHEN Count(o.PatientMasterVisitId) > 0 THEN 1	ELSE 0 END FROM dtl_PatientPharmacyOrder d INNER JOIN ord_PatientPharmacyOrder o
				ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
				WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND o.PatientId = t.PatientId AND d.Drug_Pk = 1702)
		  FROM PatientTreatmentTrackerView t
		  WHERE t.Regimen IS NOT NULL AND Year(t.RegimenStartDate) >= 2000 AND t.PatientId = @PatientId) t
	),

	curr_treatmenttracker_cte AS (
		SELECT t.PatientId,t.Regimen, t.RegimenId,t.RegimenDate, t.regimenLine,t.TLE400
		FROM (SELECT t.RegimenId,
			Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenDate
			DESC, t.PatientMasterVisitId DESC, t.Id DESC) AS rowNum, t.PatientId, t.RegimenLine, t.Regimen, t.RegimenDate, t.TLE400
		  FROM all_treatmenttracker_cte t
		) t WHERE t.rowNum = 1
	),

	init_treatmenttracker_cte AS (
		SELECT t.TLE400,	t.PatientMasterVisitId, t.PatientId,	t.Regimen, t.RegimenId, t.ARTInitiationDate, t.regimenLine
		FROM (SELECT t.PatientMasterVisitId, t.RegimenId, Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenDate, t.PatientMasterVisitId DESC) AS rowNum,
			t.PatientId, t.RegimenLine,	t.Regimen,	CAST(t.RegimenDate AS DATE) AS ARTInitiationDate, TLE400
			FROM all_treatmenttracker_cte t) t
		WHERE t.rowNum = 1
	),

	prev_treatmenttracker_cte AS (
		SELECT t.PatientId, t.Regimen, t.RegimenId,	t.RegimenDate, t.regimenLine, t.TLE400
		FROM (SELECT att.RegimenDate,
			att.PatientId,	att.RegimenId,	att.Regimen, att.TLE400, att.regimenLine, Row_Number() OVER (PARTITION BY att.PatientId ORDER BY att.RegimenDate			DESC) AS RowNum
			FROM curr_treatmenttracker_cte t
			INNER JOIN all_treatmenttracker_cte att ON t.PatientId = att.PatientId
				AND (t.RegimenId <> att.RegimenId OR (t.RegimenId = att.RegimenId AND t.TLE400 <> t.TLE400))) t
		WHERE t.RowNum = 1
	)

	SELECT @CurrentRegimenStart = CAST(MIN(ptt.RegimenDate) AS DATE) 
	FROM all_treatmenttracker_cte ptt 
	WHERE RegimenId = (SELECT RegimenId FROM curr_treatmenttracker_cte)
	
	select top 1 a.orderdate,c.ResultDate,b.ResultValue,Undetectable from ord_laborder a inner join [dtl_LabOrderTestResult] b on a.id = b.laborderid inner join dtl_LabOrderTest c on a.id = c.laborderid
	where a.ptn_pk = @ptn_pk and b.labtestid = 3 and c.labtestid = 3 and (b.ResultValue is not null or b.Undetectable is not null)
	AND a.OrderDate >= @CurrentRegimenStart
	order by a.orderdate desc

	-- Current Regimen for >= 3 months
	DECLARE @CurrentRegimen varchar(20) = (select top 1 RegimenType from ord_PatientPharmacyOrder a inner join dtl_regimenmap b on a.ptn_pharmacy_pk = b.orderID where a.ptn_pk = @ptn_pk and a.deleteflag = 0 order by a.DispensedByDate desc);
	DECLARE @Regimen3MAgo varchar(20) = (select top 1 RegimenType from ord_PatientPharmacyOrder a inner join dtl_regimenmap b on a.ptn_pharmacy_pk = b.orderID where a.ptn_pk = @ptn_pk and a.deleteflag = 0 and a.DispensedByDate <= dateadd(month, -3, getdate()) order by a.DispensedByDate desc);
	DECLARE @counter int = 1;
	DECLARE @SumCurrentRegimen int = 0;
	DECLARE @SumRegimen3MAgo int = 0;

	WHILE @counter <= DATALENGTH(@CurrentRegimen)
	   BEGIN
	   SET @SumCurrentRegimen = @SumCurrentRegimen + ASCII(SUBSTRING(@CurrentRegimen, @counter, 1))
	   SET @counter = @counter + 1
	   END
	   

	SET @counter = 1
	WHILE @counter <= DATALENGTH(@Regimen3MAgo)
	   BEGIN
	   SET @SumRegimen3MAgo = @SumRegimen3MAgo + ASCII(SUBSTRING(@Regimen3MAgo, @counter, 1))
	   SET @counter = @counter + 1
	   END
	   
	If(@SumCurrentRegimen > 0)
	BEGIN
		If(@SumCurrentRegimen = @SumRegimen3MAgo)
		BEGIN
			SELECT 1 SameRegimenFor3Months
		END
		ELSE
		BEGIN
			SELECT 0 SameRegimenFor3Months
		END
	END
	ELSE
	BEGIN
		SELECT 0 SameRegimenFor3Months
	END

	--- Completed 6 months of IPT
	/*	
	select sum(duration) TotalIPTDuration
	from ord_patientpharmacyorder a inner join dtl_patientpharmacyorder b on a.ptn_pharmacy_pk = b.ptn_pharmacy_pk
	inner join mst_drug c on b.Drug_pk = c.Drug_pk
	where drugname like '%isonia%' and ptn_pk = @ptn_pk
	UNION 
	*/
	SELECT TOP 1 180 as TotalIPTDuration FROM PatientIptOutcome i WHERE i.IptEvent = 525 /*Completed*/ AND PatientId = @PatientId -- Assign 180 if Patient has IPT outcome

	-- No Active OIs
	select top 1 cast(a.AnyComplaint as varchar) AnyComplaint from ComplaintsHistory a inner join patientmastervisit b on a.patientmastervisitid = b.id
	where a.PatientId = @PatientId and a.deleteflag = 0 and a.AnyComplaint = 1 and PatientMasterVisitId in (select Id from patientmastervisit where PatientId = @PatientId and deleteflag = 0 and VisitDate >= dateadd(month, -6, getdate()))
	UNION
	select b.Name from PhysicalExamination a inner join lookupitem b on a.ExamId = b.Id inner join patientmastervisit c on a.PatientMasterVisitId = c.Id
	where a.PatientId = @PatientId and a.deleteflag = 0 and b.Name <> 'None' and PatientMasterVisitId in (select Id from patientmastervisit where PatientId = @PatientId and deleteflag = 0 and VisitDate >= dateadd(month, -6, getdate()))
	UNION
	select top 1 cast(a.OnAntiTbDrugs as varchar) OnAntiTbDrugs from PatientICF a inner join patientmastervisit b on a.patientmastervisitid = b.id
	where a.PatientId = @PatientId and a.deleteflag = 0 and a.OnAntiTbDrugs = 1 and PatientMasterVisitId in (select Id from patientmastervisit where PatientId = @PatientId and deleteflag = 0 and VisitDate >= dateadd(month, -6, getdate()))

	-- ON ART >= 12 months
	SELECT TOP 1 CASE WHEN DATEDIFF(MONTH, RegimenStartDate, GETDATE()) >= 12 THEN 1 ELSE 0 END as OnARTFor12M  FROM PatientTreatmentTrackerView WHERE PatientId = @PatientId AND RegimenStartDate IS NOT NULL ORDER BY RegimenStartDate


END
