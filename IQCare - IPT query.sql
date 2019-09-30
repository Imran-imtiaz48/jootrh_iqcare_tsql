/*
select count(*) from PregnancyIndicator

select count(*) from PatientPregnancyIntentionAssessment

select count(*) from PatientFamilyPlanning

select * from PatientIcf WHERE PatientId = 49

select * from PatientIptWorkup WHERE PatientId = 49
select * from PatientIptOutcome WHERE PatientId = 49
*/
DECLARE @endDate AS DATE = '2018-12-31'
SELECT 
	PatientId, EverBeenOnIpt,IptStartDate,Completed,OnIpt,Discontinued,ReasonForDiscontinuation,rfd,CodedRFD
FROM (
	SELECT 
		icf.PatientId
		,CASE WHEN iptOutcome.IptEvent IS NOT NULL THEN 'Y' ELSE CASE WHEN iptStart.IptStartDate IS NOT NULL THEN 'Y' ELSE CASE WHEN icf.EverBeenOnIpt = 1 THEN 'Y' ELSE 'N' END END END as EverBeenOnIpt, l1.Name
		,CAST(iptStart.IptStartDate AS  DATE) AS IptStartDate
		,CASE WHEN l1.Name = 'Completed' THEN 'Y' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) >=6 AND l1.Name IS NULL THEN 'Y'  ELSE 'N' END END AS Completed
		,CASE WHEN l1.Name IS NOT NULL THEN 'N' ELSE CASE WHEN DATEDIFF(M,IptStartDate,@endDate) <6 THEN 'Y'  ELSE 'N' END END AS OnIpt
		,CASE WHEN l1.Name = 'Discontinued' THEN 'Y' ELSE 'N' END AS Discontinued 
		,CASE WHEN l1.Name = 'Discontinued' THEN 
			CASE WHEN l2.Name IS NOT NULL THEN l2.Name 
			ELSE 
				CASE WHEN iptOutcome.ReasonForDiscontinuation LIKE '%rashes%' OR iptOutcome.ReasonForDiscontinuation LIKE '%ar%' OR iptOutcome.ReasonForDiscontinuation LIKE '%adverse%' OR iptOutcome.ReasonForDiscontinuation LIKE '%peripheral%' OR iptOutcome.ReasonForDiscontinuation LIKE '%adh%' OR iptOutcome.ReasonForDiscontinuation LIKE '%pn%'  OR iptOutcome.ReasonForDiscontinuation LIKE '%oedema%' OR iptOutcome.ReasonForDiscontinuation LIKE '%vl%' OR iptOutcome.ReasonForDiscontinuation LIKE '%numb%' OR iptOutcome.ReasonForDiscontinuation LIKE '%toxi%' OR iptOutcome.ReasonForDiscontinuation LIKE '%a/e%' OR iptOutcome.ReasonForDiscontinuation LIKE '%rash%'           THEN 'Toxicity' ELSE  CASE WHEN iptOutcome.ReasonForDiscontinuation LIKE '%TB%' THEN 'TB' ELSE 'Stopped' END 
				END 
			END 
		ELSE NULL END AS ReasonForDiscontinuation
		,ReasonForDiscontinuation as RFD
		,l2.Name as CodedRFD
	FROM 
		(
			SELECT PatientId,MAX(CAST(EverBeenOnIpt AS INT)) AS EverBeenOnIpt FROM PatientIcf GROUP BY PatientId  
		) icf 
	LEFT JOIN 
		(
			SELECT PatientId, MAX(IptStartDate) as IptStartDate FROM PatientIptWorkup GROUP BY PatientId
		) 
		iptStart ON icf.PatientId = iptStart.PatientId
	LEFT JOIN 
		(
			SELECT * FROM (
				SELECT PatientId,ReasonForDiscontinuation,IptDiscontinuationReason,IptEvent, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIptOutcome 
			) o WHERE o.RowNum = 1
		)
		iptOutcome ON iptOutcome.PatientId = icf.PatientId
	LEFT JOIN LookupItem l1 ON l1.Id = IptEvent 
	LEFT JOIN LookupItem l2 ON l2.id = IptDiscontinuationReason
) r -- WHERE   Discontinued = 'Y'

-- rashes , adr adverse,peripheral,adh,PN,oedema,vl,numb,toxi,a/e,rash
-- startedIPT PatientIptWorkup
-- iptoutcome PatientIptOutcome


