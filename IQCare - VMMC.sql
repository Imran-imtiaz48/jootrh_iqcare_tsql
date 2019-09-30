-- Encounters and data entry personell
-- VMMC/EIMC Enrollments
-- EIMC Enrollments
-- VMMC follow up
-- EIMC followup

DECLARE @startDate AS Date = '2015-01-01'
DECLARE @endDate AS Date  = '2019-07-31'

;WITH vmmc_cte AS (
	SELECT 
		'VMMC' AS Form,
		CAST(vs.VisitDate AS DATE) AS VisitDate,
		p.PatientClinicID, 
		UPPER(CONCAT(p.dFirstName, ' ', p.dLastName)) AS ClientName, 
		v.TheatreRegNo, 
		CAST(V.VMMCDateCircumcision AS DATE) As CircumcisionDate, 
		CAST(vf.[Date] AS DATE) AS FollowupDate,
		v.CreateDate AS FirstEntryDate, 
		CONCAT(u.UserFirstName, ' ', u.UserLastName) AS EnrollmentStaffName, 
		u1.CreateDate as FollowupEntryDate, 
		CONCAT(u1.UserFirstName, ' ', u1.UserLastName) AS FollowupEntryStaffName
	FROM DTL_FBCUSTOMFIELD_Voluntary_Medical_Male_Circumcision_Client_Form v 
	INNER JOIn ord_Visit vs ON vs.Visit_Id = v.Visit_Pk  
	INNER JOIN mst_User u ON v.UserId = u.UserID
	INNER JOIN IQTools_KeHMIS.dbo.mst_patient_decoded p ON p.Ptn_Pk = v.Ptn_pk
	LEFT JOIN DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form vf ON vf.Ptn_pk = v.Ptn_pk
	LEFT JOIN mst_User u1 ON u1.UserID = vf.UserId
	--ORDER BY v.CreateDate DESC
	UNION

	SELECT 
		'EIMC' AS Form,
		CAST(vs.VisitDate AS DATE) AS VisitDate,
		p.PatientClinicID, 
		UPPER(CONCAT(p.dFirstName, ' ', p.dLastName)) AS ClientName, 
		v.TheatreRegNo, 
		CAST(V.VMMCDateCircumcision AS DATE) As CircumcisionDate, 
		CAST(vf.[Date] AS DATE) AS FollowupDate,
		v.CreateDate AS FirstEntryDate, 
		CONCAT(u.UserFirstName, ' ', u.UserLastName) AS EnrollmentStaffName, 
		u1.CreateDate as FollowupEntryDate, 
		CONCAT(u1.UserFirstName, ' ', u1.UserLastName) AS FollowupEntryStaffName
	FROM DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form v 
	INNER JOIn ord_Visit vs ON vs.Visit_Id = v.Visit_Pk  
	INNER JOIN mst_User u ON v.UserId = u.UserID
	INNER JOIN IQTools_KeHMIS.dbo.mst_patient_decoded p ON p.Ptn_Pk = v.Ptn_pk
	LEFT JOIN DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form vf ON vf.Ptn_pk = v.Ptn_pk
	LEFT JOIN mst_User u1 ON u1.UserID = vf.UserId

	UNION

	SELECT 
		'Shangring' AS Form,
		CAST(vs.VisitDate AS DATE) AS VisitDate,
		p.PatientClinicID, 
		UPPER(CONCAT(p.dFirstName, ' ', p.dLastName)) AS ClientName, 
		v.TheatreRegNo, 
		CAST(V.VMMCDateCircumcision AS DATE) As CircumcisionDate, 
		CAST(vf.[Date] AS DATE) AS FollowupDate,
		v.CreateDate AS FirstEntryDate, 
		CONCAT(u.UserFirstName, ' ', u.UserLastName) AS EnrollmentStaffName, 
		u1.CreateDate as FollowupEntryDate, 
		CONCAT(u1.UserFirstName, ' ', u1.UserLastName) AS FollowupEntryStaffName
	FROM DTL_FBCUSTOMFIELD_ShangRing_Device_Male_Circumcision_Client_Form v 
	INNER JOIn ord_Visit vs ON vs.Visit_Id = v.Visit_Pk  
	INNER JOIN mst_User u ON v.UserId = u.UserID
	INNER JOIN IQTools_KeHMIS.dbo.mst_patient_decoded p ON p.Ptn_Pk = v.Ptn_pk
	LEFT JOIN DTL_FBCUSTOMFIELD_PrePex_and_ShangRing_Follow_Up_Form vf ON vf.Ptn_pk = v.Ptn_pk
	LEFT JOIN mst_User u1 ON u1.UserID = vf.UserId
) 

SELECT * FROM vmmc_cte WHERE VisitDate BETWEEN @StartDate and @endDate

--ORDER BY v.CreateDate DESC

return
SELECT * FROM DTL_FBCUSTOMFIELD_PrePex_and_ShangRing_Follow_Up_Form order by CreateDate DESC


SELECT * FROM DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form


SELECT v.Ptn_pk,v.Visit_Pk, vf.Ptn_pk, vf.Visit_Pk FROM DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form v
INNER JOIN DTL_FBCUSTOMFIELD_Voluntary_Medical_Male_Circumcision_Client_Form vf ON vf.Ptn_pk =v.Ptn_pk
WHERE v.Ptn_pk = 32874


select * from IQTools_KeHMIS.dbo.mst_patient_decoded

select * from mst_Decode  WHERE id = 1614
