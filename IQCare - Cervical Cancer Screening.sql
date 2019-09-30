DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate ='2019-04-01';
set @endDate = GETDATE();
-- SET @endDate = DATEADD(D,-1,DATEADD(M,3,@startDate))



WITH all_Patients_cte as (
	SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,UPPER(tp.ContactName) AS ContactName, EnrollmentNumber, UPPER(tp.PatientName) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, DATEDIFF(M, [EnrollmentDate ], @endDate)/12 AS RegistrationAge, DATEDIFF(M, DateOfBirth, @endDate)/12 AS currentAge, '' AS EnrolledAt, CAST(CASE WHEN Ti.TransferInDate IS NOT NULL THEN ti.TransferInDate ELSE [EnrollmentDate ] END AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, 
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
	LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address, p.PatientName FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
	LEFT JOIN PatientTransferIn TI on TI.PatientId = g.Id
	LEFT JOIN (
			SELECT PatientId,
			CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
		  FROM PatientAppointment X
		 WHERE AppointmentDate > @endDate 
		  GROUP BY X.PatientId
	 ) P ON g.Id = p.patientId 
 ),

 cacx_q_screening_type AS (
	 SELECT 
		ps.PatientMasterVisitId,
		ps.PatientId,
		l1.DisplayName AS ScreeningQuestion,
		l2.DisplayName AS SCreeningType
	 FROM PatientScreening ps
	 INNER JOIN LookupMaster l1 ON l1.Id = ps.ScreeningCategoryId
	 INNER JOIN LookupItem l2 ON l2.Id = ps.ScreeningValueId
	 WHERE 
		ScreeningTypeId = 422 
		AND l1.Name = 'Screening'
 ),

 cacx_q_treatment_type AS (
	 SELECT 
		ps.PatientMasterVisitId,
		ps.PatientId,
		l1.DisplayName AS ScreeningQuestion,
		l2.DisplayName AS TreatmentType
	 FROM PatientScreening ps
	 INNER JOIN LookupMaster l1 ON l1.Id = ps.ScreeningCategoryId
	 INNER JOIN LookupItem l2 ON l2.Id = ps.ScreeningValueId
	 WHERE 
		ScreeningTypeId = 422 
		AND l1.Name = 'CxCaTreatment'
 ),

 cacx_q_screening_method AS (
	 SELECT 
		ps.PatientMasterVisitId,
		ps.PatientId,
		l1.DisplayName AS ScreeningQuestion,
		l2.DisplayName AS ScreeningMethod
	 FROM PatientScreening ps
	 INNER JOIN LookupMaster l1 ON l1.Id = ps.ScreeningCategoryId
	 INNER JOIN LookupItem l2 ON l2.Id = ps.ScreeningValueId
	 WHERE 
		ScreeningTypeId = 422 
		AND l1.Name = 'CxCaScreeningMethod'
 ),


 cacx_q_screening_result AS (
	 SELECT 
		ps.PatientMasterVisitId,
		ps.PatientId,
		l1.DisplayName AS ScreeningQuestion,
		l2.DisplayName AS SCreeningResult
	 FROM PatientScreening ps
	 INNER JOIN LookupMaster l1 ON l1.Id = ps.ScreeningCategoryId
	 INNER JOIN LookupItem l2 ON l2.Id = ps.ScreeningValueId
	 WHERE 
		ScreeningTypeId = 422 
		AND l1.Name IN ('VIA','VILI','PAPSMEAR','HPVTEST')
 ),


 cacx_screening_cte AS (
	SELECT 
		DISTINCT
		c.PatientId,
		c.VisitDate,
		st.ScreeningType,
		tt.TreatmentType,
		sm.ScreeningMethod,
		sr.SCreeningResult
	FROM PatientCErvicalCancerScreening c 
	INNER JOIN cacx_q_screening_type st 
		ON st.PatientMasterVisitId = c.PatientMasterVisitId AND st.PatientId = c.PatientId
	LEFT JOIN cacx_q_treatment_type tt 
		ON tt.PatientMasterVisitId = c.PatientMasterVisitId AND tt.PatientId = c.PatientId
	LEFT JOIN cacx_q_screening_method sm 
		ON sm.PatientMasterVisitId = c.PatientMasterVisitId AND sm.PatientId = c.PatientId
	LEFT JOIN cacx_q_screening_result sr
		ON sr.PatientMasterVisitId = c.PatientMasterVisitId AND sr.PatientId = c.PatientId		
 )

 SELECT 
	DISTINCT
	p.PatientID AS ID,
	p.PatientName,
	p.EnrollmentNumber AS PatientId,
	p.CurrentAge, 
	P.Sex,
	c.VisitDate,
	c.ScreeningType,
	c.ScreeningMethod,
	c.SCreeningResult,
	c.TreatmentType
FROM all_Patients_cte p
INNER JOIN cacx_screening_cte c ON p.PatientID = c.PatientId
WHERE c.VisitDate BETWEEN @startDate AND @endDate
ORDER BY c.VisitDate DESC


 /*
 SELECT 
	l1.Name,
	l1.DisplayName AS ScreeningQuestion,
	l2.Name AS SCreeningResponse
 FROM PatientScreening ps
 INNER JOIN LookupMaster l1 ON l1.Id = ps.ScreeningCategoryId
 INNER JOIN LookupItem l2 ON l2.Id = ps.ScreeningValueId
 WHERE ScreeningTypeId = 422 AND PatientMasterVisitId = 249466

 select * from LookupItemView WHERE MasterName = 'CervicalCancerScreening'

 SELECT * FROM LookupITem WHERE id IN (
 SELECT Distinct SCreeningTypeId FROM PatientScreening WHERE PatientMasterVisitId = 249466
 )
 */