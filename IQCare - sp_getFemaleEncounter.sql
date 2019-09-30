IF EXISTS(SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_getFemaleEncounters') AND type = 'P')
	DROP PROCEDURE  sp_getFemaleEncounters
GO

CREATE PROCEDURE sp_getFemaleEncounters @PatientId INT AS
BEGIN
	WITH all_pia_cte AS (
			SELECT pia.PatientId,pia.VisitDate,pia.PlanningToConceive3M,pia.RegularMenses,pia.InitiatedOnART,pia.ClientEligibleForFP,l1.DisplayName as PartnerHIVStatus,l2.DisplayName as ServiceForEligibleClient,l3.DisplayName as ReasonForFPIneligibility,pia.patientMasterVisitId, pia.InitiatedOnART as LinkedToANC
			FROM PatientPregnancyIntentionAssessment pia 
			LEFT JOIN LookupItem l1  on pia.PartnerHivStatus = l1.Id
			LEFT JOIN LookupItem l2  on pia.ServiceForEligibleClient = l2.Id
			LEFT JOIN LookupItem l3  on pia.ReasonForFPIneligibility = l3.Id
			WHERE PatientId = @PatientId
	),

	fp_method_cte AS (
		SELECT      DISTINCT fp.patientMasterVisitId, fpm.PatientId, l.DisplayName AS FPMethod,fp.VisitDate, fp.ReasonNotOnFPId
		FROM            PatientFamilyPlanning AS fp INNER JOIN
									PatientFamilyPlanningMethod AS fpm ON fp.Id = fpm.PatientFPId INNER JOIN
									LookupItem AS l ON fpm.FPMethodId = l.Id
		WHERE fp.PatientId = @PatientId
	),

	fp_cte AS (
		SELECT fp.id, PatientId, CASE fp.FamilyPlanningStatusId WHEN  1 THEN 'Y' WHEN 2 THEN 'N' ELSE 'W' END AS CurrentlyOnFp, l.DisplayName as ReasonNotOnFp,VisitDate,PatientMasterVisitId 
		FROM PatientFamilyPlanning fp LEFT JOIN LookupItem l ON fp.ReasonNotOnFPId = l.Id 
		WHERE PatientId = @PatientId
	),

	all_pregnancy_cte AS (
		SELECT * FROM (
			SELECT PatientID, PregnancyStatus, CAST(LMP AS DATE) AS LMP, CAST(EDD AS DATE) AS EDD,VisitDate,Outcome,DateOfOutcome,PatientMasterVisitId , [ANC/PNC],Parity FROM (
				SELECT        PI.Id, PI.PatientId, PI.LMP, CASE WHEN L1.Name ='NPG' THEN NULL ELSE PI.EDD END AS EDD, CAST(PI.CreateDate AS DATE) as VisitDate, L1.DisplayName AS PregnancyStatus,P.Outcome,P.DateOfOutcome,pi.PatientMasterVisitId,CASE WHEN l1.Name = 'PG' THEN 'ANC' ELSE CASE pi.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END END AS [ANC/PNC],Parity 
				FROM            PregnancyIndicator AS PI INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
				LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND P.PatientMasterVisitId = PI.PatientMasterVisitId
				WHERE pi.PatientId < = @PatientId		
			) pgs 
		) p  
	),

	all_fp_pia_cte AS (
		SELECT 
			pia.PatientId,pia.PatientMasterVisitId,pr.PregnancyStatus,pr.LMP,pr.EDD,pr.[ANC/PNC],fp.CurrentlyOnFp,fp.ReasonNotOnFP,pia.ClientEligibleForFP,pia.PlanningToConceive3M,pia.ServiceForEligibleClient, LinkedToANC 
			,FpMethods = STUFF((
					SELECT ',' + fpm.FpMethod
					FROM fp_method_cte fpm
					WHERE fpm.PatientMasterVisitId = fp.PatientMasterVisitId 
					FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
			CAST(pia.VisitDate AS DATE) as VisitDate
		FROM all_pia_cte pia  
		LEFT JOIN fp_cte fp ON fp.PatientMasterVisitId = pia.PatientMasterVisitId 
		LEFT JOIN all_pregnancy_cte pr ON pr.PatientMasterVisitId = pia.PatientMasterVisitId	 	
	)

	SELECT TOP 10 * FROM all_fp_pia_cte ORDER BY VisitDate DESC
END
