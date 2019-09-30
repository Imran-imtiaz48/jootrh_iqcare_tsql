DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

IF OBJECT_ID('tempdb..#tmpV') IS NOT NULL
	DROP TABLE #tmpV

IF OBJECT_ID('tempdb..#tmpP') IS NOT NULL
	DROP TABLE #tmpP

set @startDate ='2018-10-01';
set @endDate = '2019-03-31';
-- SET @endDate = DATEADD(D,-1,DATEADD(M,3,@startDate))

set @midDate = '2018-06-30'; -- used when comparing the effectiveness of Viremia clinic - pre and post

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw=='

;WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,UPPER(tp.ContactName) AS ContactName, EnrollmentNumber, UPPER(CONCAT(g.FirstName, ' ', REPLACE(g.MiddleName, char(0),'') , ' ', g.LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason END 
PatientStatus, CAST(ce.ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, MaritalStatus, EducationLevel,ce.ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
--INNER JOIN PatientContact
 LEFT JOIN (
	SELECT PatientId,ExitReason,ExitDate,TransferOutfacility,CreatedBy FROM (
		SELECT PatientId,l.Name AS ExitReason,ExitDate,TransferOutfacility,CreatedBy,ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM patientcareending ce INNER JOIN LookupItem l ON
		l.Id = ce.ExitReason
		WHERE ce.DeleteFlag = 0 AND ce.ExitDate < @startDate
	) ce WHERE rowNum = 1
 ) ce ON g.Id = ce.PatientId
LEFT JOIN (
	SELECT PersonId, MobileNumber, AlternativeNumber,EmailAddress FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PersonId ORDER BY CreateDate) as RowNum, PC.PersonId, PC.MobileNumber, PC.AlternativeNumber,PC.EmailAddress FROM PersonContactView PC
	) pc1 WHERE pc1.RowNum = 1
) PC ON PC.PersonId = g.PersonId	
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
LEFT JOIN (
		SELECT PatientId,
		CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM PatientAppointment X
	 WHERE AppointmentDate > @endDate 
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
-- WHERE g.PatientStatus = 'Death'
 )

SELECT DISTINCT
	a.PatientID, a.EnrollmentNumber, a.PatientName, a.NextAppointmentDate,
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus
INTO #tmpP
FROM all_Patients_cte a


;WITH providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
),

all_visits_cte AS (
	SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId, ProviderName,UserId,GroupId FROM (
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID,ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY VisitDate DESC) as RowNum FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as ProviderId FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
			UNION
			SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			UNION
			SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
	) visits WHERE VisitDate < = @endDate AND RowNum = 1
)

SELECT DISTINCT v.PatientId,v.VisitDate
INTO #tmpV
FROM (SELECT * FROM all_visits_cte v WHERE v.VisitDate BETWEEN @startDate AND @endDate ) v 
WHERE v.VisitDate BETWEEN @startDate AND @endDate 


SELECT * FROM #tmpP p WHERE p.PatientID IN ( 
	SELECT 
		v.PatientId
		FROM #tmpV v 
		WHERE
		  DATEDIFF(D, (SELECT TOP 1 VisitDate FROM #tmpV pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC), v.VisitDate) BETWEEN 84 AND 90
		GROUP BY PatientId
		HAVING COUNT(*) >= 1
) AND p.PatientStatus = 'Active'
return

SELECT v.PatientId, v.VisitDate, PrevVisitDate = 
(
	SELECT TOP 1 VisitDate FROM #tmpV pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC
) 
FROM #tmpV v
WHERE
--PatientID = 5248 AND
	DATEDIFF(D, (SELECT TOP 1 VisitDate FROM #tmpV pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC), v.VisitDate) BETWEEN 80 AND 84
/*

SELECT
v.PatientId,
COUNT(*) Visits
-- v.VisitDate, 
-- PrevVisitDate = (SELECT TOP 1 VisitDate FROM #tmpV pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC),
-- DATEDIFF(M,(SELECT TOP 1 VisitDate FROM all_visits_cte pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC),v.VisitDate) AS VisitDuration,
-- v.ProviderName 
FROM #tmpV v 
WHERE
  DATEDIFF(D, (SELECT TOP 1 VisitDate FROM #tmpV pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC), v.VisitDate) BETWEEN 84 AND 90
-- AND v.patientId = 5109
GROUP BY PatientId
HAVING COUNT(*) >= 2

*/


return

-- % Patients in care with 2 or more HIV clinical visits, 3 months apart during the 6-month review period (I)
SELECT * FROM (
	SELECT DISTINCT v.PatientId FROM all_visits_cte v
	WHERE v.VisitDate BETWEEN @startDate AND @endDate
	GROUP BY v.PatientId
	HAVING COUNT(v.PatientId) >= 2
) visitsGt2
INNER JOIN (
	SELECT v.PatientId,v.VisitDate, PrevVisitDate = (SELECT TOP 1 VisitDate FROM all_visits_cte pvv WHERE pvv.PatientId = v.PatientId AND pvv.VisitDate < v.VisitDate ORDER BY pvv.VisitDate DESC),v.ProviderName FROM all_visits_cte v 
	WHERE  v.VisitDate BETWEEN @startDate AND @endDate AND v.patientId = 834
) visitsAll ON visitsGt2.PatientId = visitsAll.PatientId




