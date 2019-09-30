SELECT PatientId, ProviderName, VisitDate FROM (
	SELECT e1.PatientId, lp.ProviderName, e1.VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY VisitDate DESC) rowNum 
	FROM (
			SELECT CreatedBy,VisitDate,PatientId FROM (
					SELECT CreatedBy, VisitDate, PatientId FROM PatientMasterVisit WHERE CreatedBy > 1
					UNION
					SELECT CreatedBy, Createdate VisitDate, PatientId FROM PatientEncounter WHERE CreatedBy > 1 
					UNION
					SELECT v.CreatedBy, v.VisitDate, p.id PatientId FROM ord_Visit v INNER JOIN patient p ON v.Ptn_Pk=p.ptn_pk WHERE v.CreatedBy > 1 
				) v
			) e1
			INNER JOIN (
				SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
				INNER JOIN mst_User u ON u.UserID = lg.UserID
				WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')					
	) lp ON lp.UserID = e1.CreatedBy
) v WHERE rowNum = 1