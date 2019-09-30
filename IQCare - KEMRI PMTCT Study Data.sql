USE IQTools_KeHMIS
GO

DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2017-01-01';
set @endDate = '2019-12-31';

SELECT        
p.PatientPK, p.MaritalStatus, p.PopulationCategory, p.PatientSource, p.PatientType, DateConfirmedHIVPositive, RegistrationAtCCC, PreviousARTExposure, p.PreviousARTStartDate, StatusAtCCC,
art.StartARTDate,art.StartRegimen,
bwho.bWHO AS BaselineWHO,
pregimen.NoOfPreviousRegimen,
baselineVL.[Test Tesult] AS BaselineVL,
art.ExitReason,art.ExitDate
FROM            tmp_PatientMaster AS p
LEFT JOIN IQC_bWHO bWHO ON bWHO.PatientPK = p.PatientPK
LEFT JOIN tmp_ARTPatients art ON art.PatientPK = p.PatientPK
LEFT JOIN (select DISTINCT PatientPk, COUNT (DISTINCT Drug) - 1 AS NoOfPreviousRegimen from tmp_Pharmacy WHERE (Drug NOT LIKE '%cotri%' AND Drug NOT LIKE '%isonia%')
GROUP BY PatientPK
) pregimen ON pregimen.PatientPK = p.PatientPK
LEFT JOIN (
	SELECT * FROM (
		SELECT PatientPk, CASE WHEN ISNUMERIC(TestResult) = 1 THEN CAST(TestResult AS decimal) ELSE 0 END AS [Test Tesult], ROW_NUMBER() OVER (PARTITION BY PatientPk ORDER BY OrderedByDate) rown FROM tmp_Labs WHERE TestName LIKE'%viral%'
	) vl WHERE vl.rown = 1
) baselineVL ON baselineVL.PatientPK = p.PatientPK
INNER JOIN (
	select PatientId,MCHNumber,MCHEnrollmentDate, Ptn_pk AS PatientPk FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, ps.Ptn_pk, P.Id as PatientID, M.MCHID as MCHNumber,CAST(ps.StartDate AS DATE) as MCHEnrollmentDate FROM IQCare_CPAD.dbo.mst_Patient M 
		INNER JOIN IQCare_CPAD.dbo.Patient P ON P.ptn_pk = M.Ptn_Pk 
		LEFT JOIN IQCare_CPAD.dbo.Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk INNER JOIN IQCare_CPAD.dbo.mst_module modu ON ps.ModuleId = modu.ModuleID 
		WHERE  modu.ModuleId = 15 AND MCHID IS NOT NULL
	) ti WHERE rowNUm = 1 AND MCHEnrollmentDate <= @endDate AND MCHEnrollmentDate >= @startDate
) mch ON mch.PatientPk = p.PatientPK
WHERE p.AgeCurrent BETWEEN 15 AND 50 AND p.Gender='Female'
--AND p.PatientPK = 2455

--select * from tmp_PatientMaster WHERE PatientPK = 2455


--select count(*) from gcPatientView WHERE PatientStatus ='Active'
drop table #tmpVisits
SELECT DISTINCT v.PatientId, CAST(ISNULL(v.VisitDate, e.EncounterStartTime) AS DATE) AS VisitDate--, e.CreatedBy
INTO #tmpVisits
FROM PatientMasterVisit v INNER JOIN PatientEncounter e ON v.id = e.PatientMasterVisitId
WHERE v.VisitDate BETWEEN '2018-01-01' AND '2019-05-31'
AND e.EncounterTypeID IN (1482,1502)
ORDER BY PatientId, VisitDate

select PatientId, VisitDate, Period = CONCAT(YEAR(VisitDate),'-', RIGHT(CONCAT(0,MONTH(Visitdate)),2)) from #tmpVisits

select COUNT(*), COUNT(DISTINCT VisitDate),COUNT(*)/COUNT(DISTINCT VisitDate) AS AVgVisits from #tmpVisits

select  DISTINCT CreatedBy, u.UserFirstName, u.UserLastName from #tmpVisits v INNER JOIN mst_user u ON v.CreatedBy=u.UserId

select * from PatientEncounter WHERE CreatedBy = 37

select * from lookupitem where id = 1504

select * from mst_user

select * from lookupitemview WHERE MasterId = 108

