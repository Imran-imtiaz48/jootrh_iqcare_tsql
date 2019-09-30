USE [IQTools_KeHMIS]
GO

/****** Object:  StoredProcedure [dbo].[pr_MOH731ADX2]    Script Date: 2/21/2019 1:30:12 PM ******/
DROP PROCEDURE [dbo].[pr_MOH731ADX2]
GO

/****** Object:  StoredProcedure [dbo].[pr_MOH731ADX2]    Script Date: 2/21/2019 1:30:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[pr_MOH731ADX2]
       -- Add the parameters for the stored procedure here
	    @fromDate Datetime,@todate datetime
AS
BEGIN
       -- SET NOCOUNT ON added to prevent extra result sets from
       -- interfering with SELECT statements.
IF OBJECT_ID('tempdb..#AgeNGender') IS NOT NULL Drop Table #AgeNGender 
IF OBJECT_ID('tempdb..#AgeGroup') IS NOT NULL Drop Table #AgeGroup 
IF OBJECT_ID('tempdb..#CTE') IS NOT NULL Drop Table #CTE



Create Table #AgeNGender(Gender varchar(10), AgeGroup varchar(15)) ;

INSERT INTO #AgeNGender (Gender , AgeGroup)
values 

	('Female','10-14'),
	('Female','15-19'),
	('Female','20-24'),
	('Female','25+'),
	('Male','10-14'),
	('Male','15-19'),
	('Male','20-24'),
	('Male','25+');

Create Table #AgeGroup(AgeGroup varchar(15)) ;

INSERT INTO #AgeGroup (AgeGroup)
values 

	('<1'),
	('1-9'),
	('10-14'),
	('15-19'),
	('20-24'),
	('25+');
CREATE TABLE  #CTE (value int, dataElement varchar(20));
--declare @fromDate as datetime= N'2018-04-01',
--		@todate  as datetime = N'2018-04-30'

insert into #CTE   (value,dataElement)

	(SELECT Count(DISTINCT p.PatientPK) value, 'Y18_HV03-001' as dataElement
	FROM tmp_PatientMaster p
	WHERE p.RegistrationAtCCC BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
	  AS datetime) AND p.AgeEnrollment BETWEEN 0 AND 9 AND (p.PatientSource IS NULL
		OR p.PatientSource <> 'Transfer In') AND (p.PatientType <> 'Transit' AND
	  p.PatientType <> 'Transfer-In' or p.PatientType is null) And p.AgeEnrollment < 1)
	 
  UNION ALL

   (SELECT Count(DISTINCT p.PatientPK) value, 'Y18_HV03-002' as dataElement
	FROM tmp_PatientMaster p
	WHERE p.RegistrationAtCCC BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
	  AS datetime) AND p.AgeEnrollment BETWEEN 0 AND 9 AND (p.PatientSource IS NULL
		OR p.PatientSource <> 'Transfer In') AND p.PatientType <> 'Transit' AND
	  p.PatientType <> 'Transfer-In' And p.AgeEnrollment between 1 and 9
	 ) 
  UNION ALL

	 SELECT case when value is NUll then 0 else value end as value, 
	 CASE WHEN Gender = 'Male' THEN 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-003' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-005'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-007'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-009' END 
		 ELSE 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-004' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-006'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-008'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-010' END			 
	END AS dataElement
	FROM 
	(
	SELECT #AgeNGender.*,value FROM
	(SELECT p.Gender, dbo.fn_GetAgeGroup(p.AgeEnrollment, 'New731') AgeGroup, Count(DISTINCT p.PatientPK) value
		FROM tmp_PatientMaster p WHERE p.RegistrationAtCCC BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
		  AS datetime) AND (p.PatientSource IS NULL OR p.PatientSource <> 'Transfer In')
		  AND (p.PatientType <> 'Transit' AND p.PatientType <> 'Transfer-In' or p.PatientType is null)
		GROUP BY p.Gender, dbo.fn_GetAgeGroup(p.AgeEnrollment, 'New731')
	 ) AS A RIGHT JOIN #AgeNGender  ON A.AgeGroup=#AgeNGender.AgeGroup AND A.Gender = #AgeNGender.Gender
	 ) AS C

	 UNION ALL 

	 (Select  Count(Distinct p.PatientPK) as [value] , 'Y18_HV03-011' as dataElement 
	 FROM tmp_PatientMaster p
	WHERE p.RegistrationAtCCC BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
	  AS datetime) AND (p.PatientSource IS NULL OR p.PatientSource <> 'Transfer In')
	  AND p.PatientType <> 'Transit' AND p.PatientType <> 'Transfer-In' 
	 )

	  UNION ALL 

	  (SELECT Count(DISTINCT p.PatientPK) value, 'Y18_HV03-012' as dataElement
		FROM tmp_PatientMaster p
		WHERE p.RegistrationAtCCC BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
		  AS datetime) AND (p.PatientSource IS NULL OR p.PatientSource <> 'Transfer In')
		  AND (p.PatientType <> 'Transit' or p.PatientType is null) AND p.PopulationCategory IS NOT NULL AND
		  p.PopulationCategory <> ' General Population'
	 ) 

	  UNION ALL 

	 (Select  Count(Distinct p.PatientPK) as [value] , 'Y18_HV03-013' as dataElement 
	  FROM tmp_PatientMaster p LEFT OUTER JOIN tmp_LastStatus l ON l.PatientPK = p.PatientPK
	  LEFT JOIN tmp_Pharmacy b ON b.PatientPK = p.PatientPK WHERE p.RegistrationAtCCC <= CAST(@todate AS datetime) AND
	  p.PatientPK NOT IN (SELECT tmp_ARTPatients.PatientPK FROM tmp_ARTPatients) AND (l.ExitDate >= CAST(@todate AS datetime) OR
		l.ExitReason IS NULL) AND b.ProphylaxisType = 'CTX' AND b.ExpectedReturn >= CAST(@fromdate AS datetime) 
	 And P.AgeEnrollment <15
	 )
	  UNION ALL 

	 (Select  Count(Distinct p.PatientPK) as [value] , 'Y18_HV03-014' as dataElement 
	  FROM tmp_PatientMaster p LEFT OUTER JOIN tmp_LastStatus l ON l.PatientPK = p.PatientPK
	  LEFT JOIN tmp_Pharmacy b ON b.PatientPK = p.PatientPK WHERE p.RegistrationAtCCC <= CAST(@todate AS datetime) AND
	  p.PatientPK NOT IN (SELECT tmp_ARTPatients.PatientPK FROM tmp_ARTPatients) AND (l.ExitDate >= CAST(@todate AS datetime) OR
		l.ExitReason IS NULL) AND b.ProphylaxisType = 'CTX' AND b.ExpectedReturn >= CAST(@fromdate AS datetime) 
	 And P.AgeEnrollment >=15
	 )
	 UNION ALL 

	 (Select  Count(Distinct p.PatientPK) as [value] , 'Y18_HV03-015' as dataElement 
	 FROM tmp_PatientMaster p LEFT OUTER JOIN tmp_LastStatus l ON l.PatientPK = p.PatientPK
	  LEFT JOIN tmp_Pharmacy b ON b.PatientPK = p.PatientPK WHERE p.RegistrationAtCCC <= CAST(@todate AS datetime) AND
	  p.PatientPK NOT IN (SELECT tmp_ARTPatients.PatientPK FROM tmp_ARTPatients) AND (l.ExitDate >= CAST(@todate AS datetime) OR
		l.ExitReason IS NULL) AND b.ProphylaxisType = 'CTX' AND b.ExpectedReturn >= CAST(@fromdate AS datetime) 
	 )

  UNION ALL
  (SELECT Count(DISTINCT a.PatientPK) value, 'Y18_HV03-016' as dataElement
	FROM tmp_ARTPatients a WHERE a.RegistrationDate <= CAST(@todate AS datetime) AND
  a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
  datetime) AND (a.PreviousARTStartDate IS NULL OR a.PreviousARTStartDate BETWEEN CAST(@fromdate AS datetime) 
  AND CAST(@todate AS datetime)) AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
  (a.PatientType <> 'Transfer-In' OR a.PatientType IS NULL) And a.AgeARTStart < 1
	 ) 
  UNION ALL

   (SELECT Count(DISTINCT a.PatientPK) value, 'Y18_HV03-017' as dataElement
	FROM tmp_ARTPatients a WHERE a.RegistrationDate <= CAST(@todate AS datetime) AND
  a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
  datetime) AND (a.PreviousARTStartDate IS NULL OR a.PreviousARTStartDate BETWEEN CAST(@fromdate AS datetime) 
  AND CAST(@todate AS datetime)) AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
  (a.PatientType <> 'Transfer-In' OR a.PatientType IS NULL) And a.AgeARTStart between 1 and 9
	 ) 
  UNION ALL

	 SELECT case when value is NUll then 0 else value end as value, 
	 CASE WHEN Gender = 'Male' THEN 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-018' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-020'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-022'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-024' END 
		 ELSE 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-019' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-021'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-023'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-025' END			 
	END AS dataElement
	FROM 
	(
	SELECT #AgeNGender.*,value FROM
	(
	SELECT a.Gender, dbo.fn_GetAgeGroup(a.AgeARTStart, 'New731') ageGroup,
	  Count(DISTINCT a.PatientPK) value FROM tmp_ARTPatients a
	WHERE a.RegistrationDate <= CAST(@todate AS datetime) AND
	  a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
	  datetime) AND (a.PreviousARTStartDate IS NULL OR
		a.PreviousARTStartDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
		AS datetime)) AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
	  (a.PatientType <> 'Transfer In' OR a.PatientType IS NULL)
	GROUP BY a.Gender, dbo.fn_GetAgeGroup(a.AgeARTStart, 'New731')
	 ) AS A RIGHT JOIN #AgeNGender  ON A.AgeGroup=#AgeNGender.AgeGroup AND A.Gender = #AgeNGender.Gender
	 ) AS C

	 UNION ALL 

	 (Select  Count(Distinct a.PatientPK) as [value] , 'Y18_HV03-026' as dataElement 
	 FROM tmp_ARTPatients a WHERE a.RegistrationDate <= CAST(@todate AS datetime) AND
	  a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
	  datetime) AND (a.PreviousARTStartDate IS NULL OR
		a.PreviousARTStartDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate
		AS datetime)) AND (a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND
	  (a.PatientType <> 'Transfer In' OR a.PatientType IS NULL)
	 )

	  UNION ALL 

	  (SELECT Count(DISTINCT a.PatientPK) value, 'Y18_HV03-027' as dataElement
		FROM tmp_ARTPatients a WHERE a.RegistrationDate <= CAST(@todate AS datetime) AND
		  a.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
		  datetime) AND (a.PreviousARTStartDate IS NULL OR a.PreviousARTStartDate BETWEEN CAST(@fromdate AS datetime) 
		  AND CAST(@todate AS datetime)) AND a.PatientType <> 'Transit' AND
		  a.PatientType <> 'Transfer-In' AND PopulationCategory IS NOT NULL AND PopulationCategory <> ' General Population'
	 ) 

	 UNION ALL
  (SELECT Count(DISTINCT aa.PatientPK) value, 'Y18_HV03-028' as dataElement
	FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ARTPatients a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON c.PatientPK = a.PatientPK
  WHERE a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
    datetime) AND p.ExpectedReturn >= CAST(@fromDate AS datetime) AND
    (c.ExitReason IS NULL OR c.ExitReason <> 'Death') AND (a.PatientType <>
      'Transit' OR a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa where ageGroup='<1'
	 ) 
  UNION ALL

   (SELECT Count(DISTINCT aa.PatientPK) value, 'Y18_HV03-029' as dataElement
	FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ARTPatients a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON c.PatientPK = a.PatientPK
  WHERE a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
    datetime) AND p.ExpectedReturn >= CAST(@fromDate AS datetime) AND
    (c.ExitReason IS NULL OR c.ExitReason <> 'Death') AND (a.PatientType <>
      'Transit' OR a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa where ageGroup='1-9') 

  UNION ALL
	 SELECT case when value is NUll then 0 else value end as value, 
	 CASE WHEN Gender = 'Male' THEN 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-030' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-032'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-034'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-036' END 
		 ELSE 
			CASE WHEN AgeGroup = '10-14' THEN 'Y18_HV03-031' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-033'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-035'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-037' END			 
	END AS dataElement
	FROM 
	(
	SELECT #AgeNGender.*,value FROM
	(
	SELECT aa.Gender,aa.ageGroup,Count(aa.PatientPK) value
	FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ARTPatients a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON c.PatientPK = a.PatientPK
  WHERE a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
    datetime) AND a.StartARTDate <= CAST(@toDate AS datetime) AND
    p.ExpectedReturn >= CAST(@fromDate AS datetime) AND (c.ExitReason IS NULL OR
      c.ExitReason <> 'Death') AND (a.PatientType <> 'Transit' OR
      a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa GROUP BY aa.Gender, aa.ageGroup
	 ) AS A RIGHT JOIN #AgeNGender  ON A.AgeGroup=#AgeNGender.AgeGroup AND A.Gender = #AgeNGender.Gender
	 ) AS C

	 UNION ALL 

	 (Select  Count(Distinct aa.PatientPK) as [value] , 'Y18_HV03-038' as dataElement 
	  FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ARTPatients a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON c.PatientPK = a.PatientPK
  WHERE a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
    datetime) AND a.StartARTDate <= CAST(@toDate AS datetime) AND
    p.ExpectedReturn >= CAST(@fromDate AS datetime) AND (c.ExitReason IS NULL OR
      c.ExitReason <> 'Death') AND (a.PatientType <> 'Transit' OR
      a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa
	 )

	UNION ALL 

	(SELECT Count(DISTINCT aa.PatientPK) value, 'Y18_HV03-039' as dataElement
	FROM (SELECT a.PatientPK, a.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('yy', a.DOB, Max(p.DispenseDate)),
	'New731') ageGroup FROM tmp_ARTPatients a
	INNER JOIN (SELECT * FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
	ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID, tmp_Pharmacy.PatientPK, tmp_Pharmacy.DispenseDate,
	tmp_Pharmacy.Duration, tmp_Pharmacy.ExpectedReturn FROM tmp_Pharmacy WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
	tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
	LEFT JOIN tmp_LastStatus c ON c.PatientPK = a.PatientPK WHERE a.RegistrationDate IS NOT NULL AND a.RegistrationDate <= CAST(@toDate AS
	datetime) AND p.ExpectedReturn >= CAST(@fromDate AS datetime) AND (c.ExitReason IS NULL OR c.ExitDate > CAST(@ToDate AS DateTime)) AND
	(a.PatientType <> 'Transit' OR a.PatientType IS NULL) AND PopulationCategory IS NOT NULL AND
	PopulationCategory <> ' General Population' GROUP BY a.PatientPK, a.Gender, a.DOB) aa) 
	UNION ALL

	(Select Count(a.PatientPK) value, 'Y18_HV03-040' as dataElement From tmp_ARTPatients a
	WHERE a.StartARTDate BETWEEN dbo.fn_DateAdd('mm', -12, CAST(@fromdate AS
  datetime)) AND dbo.fn_DateAdd('mm', -12, CAST(@todate AS datetime)) AND
  (a.ExitReason IS NULL OR a.ExitReason <> 'Transfer') AND a.ExpectedReturn >
  CAST(@fromdate AS datetime))

	UNION ALL

	(Select Count(a.PatientPK) value, 'Y18_HV03-041' as dataElement FROM tmp_ARTPatients a LEFT JOIN (SELECT a.PatientPK
	  FROM tmp_ARTPatients a WHERE a.ExitReason = 'Transfer' AND a.ExitDate BETWEEN dbo.fn_DateAdd('mm',-12, CAST(@fromdate AS datetime)) AND CAST(@todate AS datetime)) b
		ON a.PatientPK = b.PatientPK WHERE a.StartARTDate BETWEEN dbo.fn_DateAdd('mm', -12, CAST(@fromdate AS
	  datetime)) AND dbo.fn_DateAdd('mm', -12, CAST(@todate AS datetime)) AND
	  b.PatientPK IS NULL)
	  UNION ALL

	(Select Count(a.PatientPK) value, 'Y18_HV03-042' as dataElement FROM ( SELECT DISTINCT a.PatientPK,a.StartARTDate,b.LastVLResult
	FROM tmp_ARTPatients a
	  INNER JOIN IQC_LastVL b ON a.PatientPK = b.PatientPK
	WHERE a.StartARTDate BETWEEN dbo.fn_DateAdd('mm', -12, CAST(@fromdate AS
	  datetime)) AND dbo.fn_DateAdd('mm', -12, CAST(@todate AS datetime)) AND
	  (a.ExitDate IS NULL OR a.ExitDate > CAST(@todate AS datetime)) AND b.LastVLResult IS NOT NULL and Floor(Replace(Replace(b.LastVLResult, '<', ''), '>', ''))<1000)a)

	  UNION ALL

	(Select Count(a.PatientPK) value, 'Y18_HV03-043' as dataElement FROM (SELECT distinct a.PatientPK
	FROM tmp_ARTPatients a
	  INNER JOIN tmp_Labs b ON a.PatientPK = b.PatientPK
	WHERE a.StartARTDate BETWEEN dbo.fn_DateAdd('mm', -12, CAST(@fromdate AS
	  datetime)) AND dbo.fn_DateAdd('mm', -12, CAST(@todate AS datetime)) AND
	  (a.ExitDate IS NULL OR a.ExitDate > CAST(@todate AS datetime)) AND
	  b.TestName LIKE '%viral%' AND b.TestResult IS NOT NULL)a)

	UNION ALL
	SELECT Case when value is NUll then 0 else value end as value, 
			CASE WHEN AgeGroup = '<1' THEN 'Y18_HV03-044'
			     WHEN AgeGroup = '1-9' THEN 'Y18_HV03-045'
				 WHEN AgeGroup = '10-14' THEN 'Y18_HV03-046' 
				 WHEN AgeGroup = '15-19' THEN 'Y18_HV03-047'
				 WHEN AgeGroup = '20-24' THEN 'Y18_HV03-048'
				 WHEN AgeGroup = '25+' THEN 'Y18_HV03-049'  		 
	END AS dataElement
	FROM (SELECT #AgeGroup.AgeGroup,value FROM  (
		SELECT aa.ageGroup,
  Count(aa.PatientPK) value
FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_PatientMaster a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Rank() OVER (PARTITION BY p.PatientPK ORDER BY
        p.DispenseDate DESC) AS Varchar) AS RowID,
        p.PatientPK,
        p.DispenseDate,
        p.Duration,
        p.ExpectedReturn
      FROM tmp_Pharmacy p
      WHERE p.DispenseDate <= CAST(@ToDate AS DateTime) AND
        (p.ProphylaxisType <> 'TB Prophylaxis' OR p.ProphylaxisType IS NULL) AND
        p.TreatmentType IN ('Prophylaxis')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
  WHERE a.RegistrationAtCCC IS NOT NULL AND a.RegistrationAtCCC <=
    CAST(@todate AS Datetime) AND p.ExpectedReturn >= CAST(@fromDate AS
    DateTime) AND (c.ExitReason IS NULL OR c.ExitReason <> 'Death')AND (a.PatientType <> 'Transit' OR
      a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa
GROUP BY aa.ageGroup ) AS A RIGHT JOIN #AgeGroup  ON A.AgeGroup=#AgeGroup.AgeGroup  ) AS C

	UNION ALL
   (SELECT Count(aa.PatientPK) value,'Y18_HV03-050' as dataElement FROM (SELECT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_PatientMaster a
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Rank() OVER (PARTITION BY p.PatientPK ORDER BY
        p.DispenseDate DESC) AS Varchar) AS RowID,
        p.PatientPK,
        p.DispenseDate,
        p.Duration,
        p.ExpectedReturn
      FROM tmp_Pharmacy p
      WHERE p.DispenseDate <= CAST(@ToDate AS DateTime) AND
        (p.ProphylaxisType <> 'TB Prophylaxis' OR p.ProphylaxisType IS NULL) AND
        p.TreatmentType IN ('Prophylaxis')) AS RP
    WHERE RP.RowID = 1) p ON a.PatientPK = p.PatientPK
    LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
  WHERE a.RegistrationAtCCC IS NOT NULL AND a.RegistrationAtCCC <=
    CAST(@todate AS Datetime) AND p.ExpectedReturn >= CAST(@fromDate AS
    DateTime) AND (c.ExitReason IS NULL OR c.ExitReason <> 'Death')AND (a.PatientType <> 'Transit' OR
      a.PatientType IS NULL)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa)

	UNION ALL
	 SELECT Case when value is NUll then 0 else value end as value, 
	CASE WHEN AgeGroup = '<1' THEN 'Y18_HV03-051'
		WHEN AgeGroup = '1-9' THEN 'Y18_HV03-052'
		WHEN AgeGroup = '10-14' THEN 'Y18_HV03-053' 
		WHEN AgeGroup = '15-19' THEN 'Y18_HV03-054'
		WHEN AgeGroup = '20-24' THEN 'Y18_HV03-055'
		WHEN AgeGroup = '25+' THEN 'Y18_HV03-056'  END AS dataElement
	FROM ( SELECT #AgeGroup.*,value FROM  
	(SELECT aa.ageGroup,
  Count(aa.PatientPK) value
FROM (SELECT DISTINCT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ClinicalEncounters e
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT', 'Prophylaxis')) AS RP
    WHERE RP.RowID = 1) p ON e.PatientPK = p.PatientPK
    INNER JOIN tmp_PatientMaster a ON a.PatientPK = e.PatientPK
    LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
  WHERE e.SymptomCategory = 'TB Screening' AND a.RegistrationAtCCC <=
    CAST(@toDate AS Datetime) AND (c.ExitReason IS NULL OR c.ExitReason <>
      'Death') AND p.DispenseDate <= CAST(@todate AS datetime) AND
    dbo.fn_DateAdd('dd', p.Duration, p.DispenseDate) >= CAST(@fromdate
    AS datetime)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa
GROUP BY aa.ageGroup) AS A RIGHT JOIN #AgeGroup  ON A.AgeGroup=#AgeGroup.AgeGroup ) as C

   UNION ALL
   (SELECT Count(aa.PatientPK) value,'Y18_HV03-057' as dataElement FROM (SELECT DISTINCT a.PatientPK,
    a.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
    'New731') ageGroup
  FROM tmp_ClinicalEncounters e
    INNER JOIN (SELECT *
    FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
        ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
        tmp_Pharmacy.PatientPK,
        tmp_Pharmacy.DispenseDate,
        tmp_Pharmacy.Duration,
        tmp_Pharmacy.ExpectedReturn
      FROM tmp_Pharmacy
      WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
        tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT', 'Prophylaxis')) AS RP
    WHERE RP.RowID = 1) p ON e.PatientPK = p.PatientPK
    INNER JOIN tmp_PatientMaster a ON a.PatientPK = e.PatientPK
    LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
  WHERE e.SymptomCategory = 'TB Screening' AND a.RegistrationAtCCC <=
    CAST(@toDate AS Datetime) AND (c.ExitReason IS NULL OR c.ExitReason <>
      'Death') AND p.DispenseDate <= CAST(@todate AS datetime) AND
    dbo.fn_DateAdd('dd', p.Duration, p.DispenseDate) >= CAST(@fromdate
    AS datetime)
  GROUP BY a.PatientPK,
    a.Gender,
    a.DOB) aa)

	UNION ALL
	 (SELECT value,'Y18_HV03-058' as dataElement FROM (SELECT Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.PatientPK, a.Gender,
		dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', a.DOB, Max(p.DispenseDate)) / 12,
		'New731') ageGroup
	  FROM tmp_ClinicalEncounters e
		INNER JOIN (SELECT *
		FROM (SELECT CAST(Row_Number() OVER (PARTITION BY tmp_Pharmacy.PatientPK
			ORDER BY tmp_Pharmacy.DispenseDate DESC) AS Varchar) AS RowID,
			tmp_Pharmacy.PatientPK,
			tmp_Pharmacy.DispenseDate,
			tmp_Pharmacy.Duration,
			tmp_Pharmacy.ExpectedReturn
		  FROM tmp_Pharmacy
		  WHERE tmp_Pharmacy.DispenseDate <= CAST(@ToDate AS DateTime) AND
			tmp_Pharmacy.TreatmentType IN ('ART', 'PMTCT')) AS RP
		WHERE RP.RowID = 1) p ON e.PatientPK = p.PatientPK
		INNER JOIN tmp_PatientMaster a ON a.PatientPK = e.PatientPK
		LEFT JOIN tmp_LastStatus c ON a.PatientPK = c.PatientPK
	  WHERE e.SymptomCategory = 'TB Screening' and Symptom in ('Suspect','Presumed TB') AND a.RegistrationAtCCC <=
		CAST(@toDate AS Datetime) AND (c.ExitReason IS NULL OR c.ExitReason <>
		  'Death') AND p.DispenseDate <= CAST(@todate AS datetime) AND
		dbo.fn_DateAdd('dd', p.Duration, e.visitdate) >= CAST(@fromdate
		AS datetime)GROUP BY a.PatientPK,a.Gender,a.DOB) aa) as a)


	UNION ALL
	SELECT Case when value is NUll then 0 else value end as value, 
	CASE WHEN AgeGroup = '<1' THEN 'Y18_HV03-059'
		WHEN AgeGroup = '1-9' THEN 'Y18_HV03-060'
		WHEN AgeGroup = '10-14' THEN 'Y18_HV03-061' 
		WHEN AgeGroup = '15-19' THEN 'Y18_HV03-062'
		WHEN AgeGroup = '20-24' THEN 'Y18_HV03-063'
		WHEN AgeGroup = '25+' THEN 'Y18_HV03-064'  END AS dataElement
	FROM (SELECT #AgeGroup.*,value FROM (SELECT aa.ageGroup, Count(aa.PatientPK) value
	FROM (SELECT a.PatientPK, a.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('yy', a.DOB, Max(b.DispenseDate)),
	'New731') ageGroup FROM tmp_PatientMaster a INNER JOIN tmp_Pharmacy b ON a.PatientPK = b.PatientPK
	INNER JOIN DTL_FBCUSTOMFIELD_Intensive_Case_Finding c ON a.PatientPK = c.Ptn_pk
	WHERE b.ProphylaxisType = 'TB Prophylaxis' AND c.IPTStartDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
	datetime) AND b.Drug LIKE 'Isoniazid%' GROUP BY a.PatientPK, a.Gender, a.DOB
	HAVING Max(b.ExpectedReturn) >= CAST(@fromDate AS datetime)) aa GROUP BY aa.ageGroup ) AS A RIGHT JOIN #AgeGroup  ON A.AgeGroup=#AgeGroup.AgeGroup ) as c

	UNION ALL
   (SELECT Count(aa.PatientPK) value,'Y18_HV03-065' as dataElement FROM (SELECT a.PatientPK, a.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('yy', a.DOB, Max(b.DispenseDate)),
	'New731') ageGroup FROM tmp_PatientMaster a INNER JOIN tmp_Pharmacy b ON a.PatientPK = b.PatientPK
	INNER JOIN DTL_FBCUSTOMFIELD_Intensive_Case_Finding c ON a.PatientPK = c.Ptn_pk
	WHERE b.ProphylaxisType = 'TB Prophylaxis' AND c.IPTStartDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
	datetime) AND b.Drug LIKE 'Isoniazid%' GROUP BY a.PatientPK, a.Gender, a.DOB
	HAVING Max(b.ExpectedReturn) >= CAST(@fromDate AS datetime)) aa)

	UNION ALL
	(SELECT  value, 'Y18_HV03-067' as dataElement
	FROM (SELECT aa.ageGroup,
	  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
		b.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
		'Normal') ageGroup
	  FROM PatientScreenigView a
		INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
	  WHERE a.NutritionStatus IS NOT NULL AND a.VisitDate BETWEEN CAST(@fromdate AS
		datetime) AND CAST(@todate AS datetime)
	  GROUP BY a.ptn_pk, b.Gender,b.DOB, a.VisitDate) aa
	GROUP BY aa.ageGroup) a where a.ageGroup='0-14')


	UNION ALL
	(SELECT  value, 'Y18_HV03-068' as dataElement
	FROM (SELECT aa.ageGroup,
	  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
		b.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
		'Normal') ageGroup
	  FROM PatientScreenigView a
		INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
	  WHERE a.NutritionStatus IS NOT NULL AND a.VisitDate BETWEEN CAST(@fromdate AS
		datetime) AND CAST(@todate AS datetime)
	  GROUP BY a.ptn_pk, b.Gender,b.DOB, a.VisitDate) aa
	GROUP BY aa.ageGroup) a where a.ageGroup='Adult')

	UNION ALL
	(SELECT  value, 'Y18_HV03-069' as dataElement
	FROM (SELECT  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
		b.Gender, dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
		'Normal') ageGroup
	  FROM PatientScreenigView a
		INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
	  WHERE a.NutritionStatus IS NOT NULL AND a.VisitDate BETWEEN CAST(@fromdate AS
		datetime) AND CAST(@todate AS datetime)
	  GROUP BY a.ptn_pk, b.Gender,b.DOB, a.VisitDate) aa) a )

	  UNION ALL
	(SELECT  value, 'Y18_HV03-070' as dataElement
	FROM (SELECT aa.ageGroup,
	  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
    b.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
    'Normal') ageGroup
  FROM PatientScreenigView a
    INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
  WHERE a.NutritionStatus IS NOT NULL AND a.NutritionStatus IN ('SAM', 'MAM')
    AND a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
    datetime)GROUP BY a.ptn_pk,b.Gender,b.DOB,a.VisitDate) aa
		GROUP BY aa.ageGroup) a where a.ageGroup='0-14')


	UNION ALL
	(SELECT  value, 'Y18_HV03-071' as dataElement
	FROM (SELECT aa.ageGroup,
	  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
    b.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
    'Normal') ageGroup
	  FROM PatientScreenigView a
		INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
	  WHERE a.NutritionStatus IS NOT NULL AND a.NutritionStatus IN ('SAM', 'MAM')
		AND a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
		datetime)GROUP BY a.ptn_pk,b.Gender, b.DOB, a.VisitDate) aa
		GROUP BY aa.ageGroup) a where a.ageGroup='Adult')

	UNION ALL
	(SELECT  value, 'Y18_HV03-072' as dataElement
	FROM (SELECT  Count(aa.PatientPK) value
	FROM (SELECT DISTINCT a.ptn_pk PatientPK,
    b.Gender,
    dbo.fn_GetAgeGroup(dbo.fn_DateDiff('mm', b.DOB, Max(a.VisitDate)) / 12,
    'Normal') ageGroup
  FROM PatientScreenigView a
    INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
  WHERE a.NutritionStatus IS NOT NULL AND a.NutritionStatus IN ('SAM', 'MAM')
    AND a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
    datetime)GROUP BY a.ptn_pk,b.Gender, b.DOB,a.VisitDate) aa) a )

	UNION ALL
   (SELECT Count(DISTINCT p.PatientPK) value,'Y18_HV03-076' as dataElement FROM tmp_TBPatients p
	WHERE p.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime))

	UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-077' as dataElement FROM tmp_TBPatients a INNER JOIN tmp_PatientMaster b ON a.PatientPK = b.PatientPK
   WHERE a.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND a.HIVTestDate < a.RegistrationAtTBClinic AND  a.HIVStatus = 'Positive')

	UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-078' as dataElement FROM tmp_TBPatients a WHERE a.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND
   CAST(@todate AS datetime) AND a.HIVTestDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime))

   UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-079' as dataElement FROM tmp_TBPatients a WHERE a.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND
   CAST(@todate AS datetime))

   UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-080' as dataElement From tmp_TBPatients a 
  Where a.RegistrationAtTBClinic Between Cast(@fromdate As datetime) And Cast(@todate As datetime) 
  And a.HIVTestDate Between Cast(@fromdate As datetime) And Cast(@todate As datetime) And a.HIVStatus = 'Positive')

  	UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-081' as dataElement FROM tmp_TBPatients a INNER JOIN tmp_PatientMaster b ON a.PatientPK = b.PatientPK
   WHERE a.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND (a.HIVTestDate < a.RegistrationAtTBClinic AND  a.HIVStatus = 'Positive')
   or (a.HIVTestDate Between Cast(@fromdate As datetime) And Cast(@todate As datetime) And a.HIVStatus = 'Positive'))

	UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-082' as dataElement FROM tmp_TBPatients a INNER JOIN tmp_ARTPatients b ON a.PatientPK = b.PatientPK
  WHERE b.StartARTDate < a.RegistrationAtTBClinic AND a.RegistrationAtTBClinic BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime)

   UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-083' as dataElement FROM tmp_TBPatients a INNER JOIN tmp_ARTPatients b ON a.PatientPK = b.PatientPK WHERE a.RegistrationAtTBClinic 
   BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND b.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime))

   UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-084' as dataElement FROM tmp_TBPatients a INNER JOIN tmp_ARTPatients b ON a.PatientPK = b.PatientPK WHERE a.RegistrationAtTBClinic 
   BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND (b.StartARTDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime)or b.StartARTDate < a.RegistrationAtTBClinic ))

   ---Cervical Cancer screening redo
   UNION ALL
   (SELECT Count(DISTINCT aa.PatientPK) value,'Y18_HV03-087' as dataElement FROM (SELECT DISTINCT a.ptn_pk PatientPK,
    b.Gender
  FROM PatientScreenigView a
    INNER JOIN tmp_PatientMaster b ON a.ptn_pk = b.PatientPK
  WHERE a.CaCx IS NOT NULL AND a.CaCx IN ('Yes') AND
    a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
    datetime) AND a.VisitDate IS NOT NULL AND b.AgeLastVisit >= 18 AND
    b.Gender = 'Female'
  GROUP BY a.ptn_pk,
    b.Gender,
    b.DOB,
    a.VisitDate) aa)
  

      UNION ALL
   (SELECT Count(DISTINCT f18.PatientPK) value,'Y18_HV03-088' as dataElement FROM (SELECT DISTINCT a.PatientPK, a.VisitDate FROM tmp_ClinicalEncounters a
    INNER JOIN tmp_PatientMaster b ON a.PatientPK = b.PatientPK WHERE a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS
    datetime) AND a.Service = 'ART' AND b.Gender = 'Female' AND dbo.fn_GetAge(b.DOB, CAST(@todate AS datetime)) >= 18) f18)

    UNION ALL
   (SELECT Count(DISTINCT a.PatientPK) value,'Y18_HV03-089' as dataElement FROM (SELECT a.PatientPK FROM tmp_ClinicalEncounters a INNER JOIN tmp_PatientMaster b ON a.PatientPK = b.PatientPK
  WHERE a.FamilyPlanningMethod != 'UND =undecided' AND a.VisitDate BETWEEN CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND b.RegistrationAtCCC IS NOT NULL 
  UNION SELECT a.PatientPK FROM tmp_ClinicalEncounters a INNER JOIN tmp_PatientMaster b ON a.PatientPK = b.PatientPK WHERE a.PwP = 'Modern contraceptive methods' AND a.VisitDate BETWEEN
  CAST(@fromdate AS datetime) AND CAST(@todate AS datetime) AND b.RegistrationAtCCC IS NOT NULL) a)


   
   )



order by dataElement asc
select * from #CTE
 --for xml raw('dataValue'),root('adx') 
END


GO


