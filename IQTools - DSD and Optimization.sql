SELECT COUNT(DISTINCT Id) ALLActive,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') <> 'Adult' THEN PatientId ELSE NULL END) ActivePaeds,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' THEN PatientId ELSE NULL END) ActiveAdults,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='M' THEN PatientId ELSE NULL END) ActiveAdultMale,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='F' THEN PatientId ELSE NULL END) ActiveAdultFemale,
COUNT(DISTINCT CASE WHEN a.[Current regimen line] =1 THEN PatientId ELSE NULL END) ALLFirstLine,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='M' AND a.[Current regimen] LIKE '%TDF + 3TC + DTG%' THEN PatientId ELSE NULL END) ActiveAdultMaleTLD,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='F' AND a.[Current regimen] LIKE '%TDF + 3TC + DTG%' THEN PatientId ELSE NULL END) ActiveAdultFemaleTLD,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') <> 'Adult' AND a.[Current regimen] LIKE '%NVP%' THEN PatientId ELSE NULL END) ActivePaedsNVP,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='M' AND a.[Current regimen] LIKE '%NVP%' THEN PatientId ELSE NULL END) ActiveAdultMaleNVP,
COUNT(DISTINCT CASE WHEN [dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') = 'Adult' AND Sex='F' AND a.[Current regimen] LIKE '%NVP%' THEN PatientId ELSE NULL END) ActiveAdultMaleNVP,
COUNT(DISTINCT CASE WHEN a.LastVLValue IS NOT NULL THEN PatientId ELSE NULL END) AllWithVL,
COUNT(DISTINCT CASE WHEN a.LastVLValue IS NOT NULL AND a.LastVLValue < 1000 THEN PatientId ELSE NULL END) AllWithVLSuppressed,
100.0 * COUNT(DISTINCT CASE WHEN a.LastVLValue IS NOT NULL AND a.LastVLValue < 1000 THEN PatientId ELSE NULL END) / SUM(COUNT(DISTINCT CASE WHEN a.LastVLValue IS NOT NULL THEN PatientId ELSE NULL END)) OVER() AS PercentSuppressed,
COUNT(DISTINCT CASE WHEN Categorization = 'Stable' THEN PatientId ELSE NULL END) AS AllStable,
COUNT(DISTINCT CASE WHEN Categorization = 'Stable' AND (DCMOdel = 'Community Based Dispensin' OR DCModel='Express Care') THEN PatientId ELSE NULL END) AS AllStableDSD,
COUNT(DISTINCT CASE WHEN a.[Current regimen] LIKE '%DTG%' THEN PatientId ELSE NULL END) AllActiveOnDTG,
COUNT(DISTINCT CASE WHEN a.[Current regimen] LIKE '%TDF + 3TC + DTG%' THEN PatientId ELSE NULL END) AllActiveOnTLD,
100.0 * COUNT(DISTINCT CASE WHEN a.[Current regimen] LIKE '%TDF + 3TC + DTG%' THEN PatientId ELSE NULL END) / SUM( COUNT(DISTINCT Id)) OVER() PercentOnTLD,
100.0 * COUNT(DISTINCT CASE WHEN Categorization = 'Stable' AND (DCMOdel = 'Community Based Dispensin' OR DCModel='Express Care') THEN PatientId ELSE NULL END) / SUM( COUNT(DISTINCT CASE WHEN Categorization = 'Stable' THEN PatientId ELSE NULL END)) OVER() PercentStableOnDS
FROM tmp_jot_201906 a
WHERE PatientStatus = 'Active' AND [Current regimen] IS NOT NULL
return

-- Not on DTG
SELECT
[Currentregimen],  Sex, COUNT(*) AS NumberOnRegimen
FROM (
	SELECT  Sex, a.LastVLSampleDate, PatientId,	REPLACE(CASE WHEN a.[Current regimen] IS NULL THEN NULL ELSE SUBSTRING(a.[Current regimen],CHARINDEX('(',a.[Current regimen])+1,LEN(a.[Current regimen]) - CHARINDEX('(',a.[Current regimen]) - 1) END, ' + ', '/') as CurrentRegimen
	FROM tmp_jot_201906 a
	WHERE PatientStatus = 'Active' AND [Current regimen] IS NOT NULL
	AND [Current regimen] NOT LIKE '%DTG%' 
) c
GROUP BY [Currentregimen], Sex
return

SELECT AgeGroup,
--[Currentregimen],  Sex, LastVLSampleDate, LastVLDate,
COUNT(DISTINCT CASE WHEN  LastVLSampleDate > LastVlDate AND DATEDIFF(M, LastVLSampleDate , '2019-07-19')<=2 THEN PatientId END) RecentlyBled,
COUNT(DISTINCT CASE WHEN  LastVLSampleDate IS NULL THEN PatientId END) NeverBled
FROM (
	SELECT  Sex,[dbo].[fn_GetAgeGroup]([Current Age], 'PEPFAR') AgeGroup, a.LastVLSampleDate, LastVLDate, PatientId,	REPLACE(CASE WHEN a.[Current regimen] IS NULL THEN NULL ELSE SUBSTRING(a.[Current regimen],CHARINDEX('(',a.[Current regimen])+1,LEN(a.[Current regimen]) - CHARINDEX('(',a.[Current regimen]) - 1) END, ' + ', '/') as CurrentRegimen
	FROM tmp_jot_201906 a
	WHERE PatientStatus = 'Active' AND [Current regimen] IS NOT NULL	
) c
WHERE [Currentregimen] LIKE 'TDF/3TC/EFV' AND Sex='M'
GROUP BY AgeGroup

--AND LastVLSampleDate > LastVlDate AND DATEDIFF(M, LastVLSampleDate , '2019-07-19')<=2
--GROUP BY [Currentregimen], Sex


 SELECT PatientId, [Current regimen], [ART Start Date], PatientStatus, NextAppointmentDate FROM tmp_jot_201906 a WHERE --PatientStatus = 'Active' 
  id = 9991

 -- AND [Current regimen] IS NOT NULL

 SELECT * FROM tmp_jot_201906

 delete from tmp_jot_201906 WHERE RegistrationDate > '2019-07-19'


 select * from tmp_PatientMaster