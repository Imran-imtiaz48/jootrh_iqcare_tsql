DECLARE @UserId INT 

SELECT @UserId = UserId from mst_User WHERE UserFirstName LIKE 'PAM%'


-- SELECT * FROM DTL_FBCUSTOMFIELD_Voluntary_Medical_Male_Circumsicion_Client_Form WHERE UserId = @UserId

-- SELECT * FROM DTL_FBCUSTOMFIELD_Voluntary_Medical_Male_Circumcision_Client_Form WHERE UserId = @UserId

--SELECT * FROM VMMC

SELECT CreateDate,COunt(*) as EIMCFormsDone FROM (
	SELECT CAST(CreateDate AS DATE) as CreateDate FROM DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form WHERE UserId = @UserId
) EIMC Group By CreateDate


SELECT CreateDate,COunt(*) as EIMCFollowUpFormsDone FROM (
	SELECT CAST(CreateDate AS DATE) as CreateDate FROM DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form WHERE UserId = @UserId
) VMMC Group By CreateDate
-- SELECT * FROM DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form  WHERE UserId = @UserId

exec pr_OpenDecryptedSession
DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form

select * from mst_User WHERE UserId = 125

SELECT * FROM DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form ORDER BY ID DESC


SELECT 
	CAST(v.VisitDate AS DATE) AS VisitDate, p.PatientClinicID, UPPER(CONCAT(CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)),' ', CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)))) as ClientName,
--	vmmc.HIVTestResult AS [HIV Status by Self Report],
	-- vmmc.HIVStatus AS [Result of HIV Status at this Facility],
--	vmmc.VMMCServiceType AS [Service Delivery Type],
--	VMMCPartnerResult AS [Partner Test Result at this Facility Today], BPSystolic,BPDiastolic, --, *  ,
	ROW_NUMBER() OVER(PARTITION BY PatientClinicId ORDER BY vmmc.CreateDate DESC) AS rown
FROM DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form vmmc 
INNER JOIN ord_Visit v ON vmmc.Visit_Pk = v.Visit_Id
INNER JOIN mst_Patient p ON p.Ptn_Pk = vmmc.Ptn_pk
WHERE vmmc.UserId = 6
--WHERE v.VisitDate BETWEEN '2019-04-01' AND '2019-05-31'
ORDER BY v.VisitDate DESC


select * from DTL_FBCUSTOMFIELD_Infant_Male_Circumcision_Client_Form


select * from DTL_FBCUSTOMFIELD_VMMC_Follow_Up_Form vmmc
WHERE vmmc.UserId = 6
--WHERE vmmc.Date BETWEEN '2019-05-01' AND '2019-05-31'
AND vmmc.UserId = 55


select * from mst_User WHERE UserFirstName lIKE '%lawrence%'

WHERE UserID 
IN (55,
125)

SELECT 
	CAST(v.VisitDate AS DATE) AS VisitDate, p.PatientClinicID, UPPER(CONCAT(CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)),' ', CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)))) as ClientName,
--	vmmc.HIVTestResult AS [HIV Status by Self Report],
	-- vmmc.HIVStatus AS [Result of HIV Status at this Facility],
--	vmmc.VMMCServiceType AS [Service Delivery Type],
--	VMMCPartnerResult AS [Partner Test Result at this Facility Today], BPSystolic,BPDiastolic, --, *  ,
	ROW_NUMBER() OVER(PARTITION BY PatientClinicId ORDER BY vmmc.CreateDate DESC) AS rown
FROM DTL_FBCUSTOMFIELD_Voluntary_Medical_Male_Circumcision_Client_Form vmmc 
INNER JOIN ord_Visit v ON vmmc.Visit_Pk = v.Visit_Id
INNER JOIN mst_Patient p ON p.Ptn_Pk = vmmc.Ptn_pk
WHERE vmmc.UserId = 6
--WHERE v.VisitDate BETWEEN '2019-05-01' AND '2019-05-31'
ORDER BY v.VisitDate DESC








