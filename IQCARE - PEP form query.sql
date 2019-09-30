DECLARE @startDate AS DATE = '2019-08-01'
DECLARE @endDate AS DATE = '2019-08-31'


SELECT 
	p.PRC_NO,p.OPD_NO,p.PP_NO,
	UPPER(CONCAT(p.dFirstName,' ', p.dMiddleName,' ',p.dLastName)) AS Name,
	sex.Name AS Sex,
	DATEDIFF(YEAR,p.DOB,v.VisitDate) AS Age,
	CAST (v.VisitDate AS DATE) AS VisitDate,
	ViolenceType.Name AS ViolenceType,
	AssaultType.Name AS AssaultType,
	CAST (pep.Date AS DATE) AS IncidenceDate,
	PerpHIVTest.Name AS PerpHIVTest,
	pep.GBVPerpFileNo,
	HIV.Name AS HivTestResult,
	PDT.Name AS PDTTestResult,
	pep.ALTAssessment as AltTestResult,
	pep.CreatAssesment AS CreatinineTestResult,
	HBsAg.Name AS HBSAGAssessmentResult,
	EC.Name AS EmergencyContraceptive,
	STIP.Name AS STIPropylaxis,
	STIT.Name AS STITreatment,
	PEPI.Name AS PEP,
	CAST(pep.AppointmentDate AS DATE) AS AppointmentDate,
	ReferredTo = STUFF((
					SELECT ',' + d.Name
					FROM dtl_FB_GBVReferredTo r
					INNER JOIN mst_ModDeCode d ON r.GBVReferredTo =d.ID 
					WHERE r.Visit_Pk = pep.Visit_Pk
					FOR XML PATH('')), 1, 1, ''),
--	p.dPhone AS Phone,
--	p.dContactName,
--	p.dContactPhone,
	UPPER(CONCAT(u.UserFirstName, ' ', u.UserLastName)) AS SeenBy
FROM DTL_FBCUSTOMFIELD_HIV_PEP_Management_Form_for_Survivors pep
INNER JOIN IQTools_KeHMIS.dbo.mst_patient_decoded p ON pep.Ptn_pk = p.Ptn_Pk
INNER JOIN mst_DeCode sex ON sex.ID = p.Sex 
INNER JOIN ord_visit v ON v.Visit_Id = pep.Visit_Pk
LEFT JOIN mst_ModDeCode ViolenceType ON ViolenceType.ID = pep.GBViolence  
LEFT JOIN mst_ModDeCode AssaultType ON AssaultType.ID = pep.GBAssault  
LEFT JOIN mst_ModDeCode PerpHIVTest ON PerpHIVTest.ID = pep.GBVPerpHIV  
LEFT JOIN mst_ModDeCode HIV ON HIV.ID = pep.HIVTestResult
LEFT JOIN mst_ModDeCode PDT ON PDT.ID = pep.GBVPDT
LEFT JOIN mst_ModDeCode HBSAG ON HBSAG.ID = pep.HBsAg
LEFT JOIN mst_ModDeCode EC ON EC.ID = pep.GBVEmerContra
LEFT JOIN mst_ModDeCode STIP ON STIP.ID = pep.GBVSTI
LEFT JOIN mst_ModDeCode STIT ON STIT.ID = pep.GBVSTITreat
LEFT JOIN mst_ModDeCode PEPI ON PEPI.ID = pep.GBVPEP
INNER JOIN mst_User u ON u.UserID = v.UserID
WHERE
	v.VisitDate BETWEEN @startDate AND @endDate
 