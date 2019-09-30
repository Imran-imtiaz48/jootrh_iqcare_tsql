DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2019-05-01';
set @endDate = '2019-07-19';

BEGIN TRY
drop table #tmpAllTreatment
drop table #tmpAllVisits
END TRY
BEGIN CATCH
END CATCH

exec pr_OpenDecryptedSession

;WITH all_treatment_cte AS (
		SELECT * FROM (
			SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
					INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
					 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
					)		
			 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
		) t
)

SELECT * 
INTO #tmpAllTreatment
FROM all_treatment_cte 


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
			--UNION
			--SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			--UNION
			--SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			--WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
		) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
	) visits WHERE VisitDate < = @endDate AND RowNum = 1
)

SELECT * 
INTO #tmpAllVisits
FROM all_visits_cte 


;WITH all_Patients_cte AS (SELECT g.Id AS PatientID,
      g.PersonId,
      PC.MobileNumber AS PhoneNumber,
      g.EnrollmentNumber,
      Upper(CONCAT(g.FirstName, ' ', g.MiddleName, ' ', g.LastName)) AS
      PatientName,
      CASE WHEN g.Sex = 52 THEN 'F' ELSE 'M' END AS Sex,
      DateDiff(M, g.[EnrollmentDate ], @endDate) / 12 AS RegistrationAge,
      DateDiff(M, g.DateOfBirth, @endDate) / 12 AS currentAge,
      '' AS EnrolledAt,
      CAST(CASE WHEN TI.TransferInDate IS NOT NULL THEN TI.TransferInDate
        ELSE g.[EnrollmentDate ] END AS Date) AS EnrollmentDate,
      '' AS ARTStartDate,
      '' AS FirstVisitDate,
      '' AS LastVisitDate,
      P.NextAppointmentDate,
      CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason
      END PatientStatus,
      CAST(ce.ExitDate AS DATE) AS ExitDate,
      g.DateOfBirth,
      g.PatientType,
      ce.ExitReason	  
    FROM gcPatientView2 g
      LEFT JOIN (SELECT ce.PatientId,
        ce.ExitReason,
        ce.ExitDate,
        ce.TransferOutfacility,
        ce.CreatedBy
      FROM (SELECT ce.PatientId,
          l.Name AS ExitReason,
          ce.ExitDate,
          ce.TransferOutfacility,
          ce.CreatedBy,
          Row_Number() OVER (PARTITION BY ce.PatientId ORDER BY ce.CreateDate
          DESC) AS RowNum
        FROM patientcareending ce
          INNER JOIN LookupItem l ON l.Id = ce.ExitReason
        WHERE ce.ExitDate < @startDate AND ce.DeleteFlag = 0) ce
      WHERE ce.RowNum = 1) ce ON g.Id = ce.PatientId
      LEFT JOIN (SELECT pc1.PersonId,
        pc1.MobileNumber,
        pc1.AlternativeNumber,
        pc1.EmailAddress
      FROM (SELECT Row_Number() OVER (PARTITION BY PC.PersonId ORDER BY
          PC.CreateDate) AS RowNum,
          PC.PersonId,
          PC.MobileNumber,
          PC.AlternativeNumber,
          PC.EmailAddress
        FROM PersonContactView PC) pc1
      WHERE pc1.RowNum = 1) PC ON PC.PersonId = g.PersonId
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = g.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM PatientAppointment X
      GROUP BY X.PatientId) P ON g.Id = P.PatientId),

 marital_status_cte AS (
	SELECT PatientId, MaritalStatus FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY m.personId ORDER BY m.CreateDate DESC) AS rown, p.id AS PatientId, m.PersonId, l.Name AS MaritalStatus FROM PatientMaritalStatus m 
		INNER JOIN LookupItem l ON m.MaritalStatusId = l.Id 
		INNER JOIN Patient p ON p.PersonId = m.PersonId
		WHERE m.DeleteFlag = 0
	) m WHERE m.rown = 1 
 ),


last_visit_cte AS (
	SELECT lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, v.VisitDate AS LastVisitdate, PatientMasterVisitId, v.ProviderId AS lastProvider, ProviderName as LastProviderName FROM #tmpAllVisits v
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId,v.UserID lastProvider, CONCAT(u.UserFirstName, ' ', u.UserLastName) as LastProviderName FROM #tmpAllVisits v INNER JOIN mst_User u ON v.UserId = u.UserID
	) lastVisit WHERE rowNum = 1
),

ti_cte AS (
	select PatientId,TiNumber FROM (                                                
		SELECT ROW_NUMBER() OVER(PARTITION BY PAtientId ORDER BY PatientId) AS rowNUm, PatientID, IdentifierValue as TINumber FROM PatientIdentifier WHERE IdentifierTypeId = 17
	) ti WHERE rowNUm = 1
),

mch_cte AS (
	select PatientId,MCHNumber,MCHEnrollmentDate FROM (
		SELECT ROW_NUMBER() OVER(PARTITION BY p.ID ORDER BY p.Id) AS rowNUm, P.Id as PatientID, M.MCHID as MCHNumber,CAST(ps.StartDate AS DATE) as MCHEnrollmentDate FROM mst_Patient M 
		INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk 
		LEFT JOIN Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk INNER JOIN mst_module modu ON ps.ModuleId = modu.ModuleID 
		WHERE  modu.ModuleId = 15 AND MCHID IS NOT NULL
	) ti WHERE rowNUm = 1
)

-- SELECT * FROM all_Patients_cte a 
-- INNER JOIN marital_status_cte m ON a.PatientID = m.PatientId

 SELECT 
	a.EnrollmentNumber AS PatientId, ti.TINumber, mch.MCHNumber, a.PatientName, a.Sex,a.currentAge,a.EnrollmentDate, a.NextAppointmentDate, m.MaritalStatus, 
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead' 
		WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) < 30 THEN 'Active' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 30 AND DATEDIFF(D,a.NextAppointmentDate,@endDate) < 90 THEN 'Defaulter' 
		WHEN DATEDIFF(D,a.NextAppointmentDate,@endDate) >= 90 OR DATEDIFF(D,a.NextAppointmentDate,@endDate) IS NULL THEN 'LTFU' 
		ELSE a.PatientStatus 
	END as PatientStatus
 FROM all_Patients_cte a 
 LEFT JOIN marital_status_cte m ON a.PatientID = m.PatientId
 LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
 LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
-- WHERE a.PatientStatus = 'Active'

