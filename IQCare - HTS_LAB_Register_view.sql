SELECT DISTINCT ISNULL(ROW_NUMBER() OVER (ORDER BY PE.Id ASC), - 1) AS RowID, P.Id PatientID, p.Ptn_pk AS PatientPK, CONVERT(varchar(50), decryptbykey(Per.firstname)) + ' ' + CONVERT(varchar(50), 
decryptbykey(Per.middlename)) + ' ' + CONVERT(varchar(50), decryptbykey(Per.lastname)) AS PatientName, p.FacilityId FacilityCode, PE.EncounterStartTime VisitDate, p.dateofbirth AS DOB, DATEdiff(yy, p.dateofbirth, 
PE.EncounterStartTime) AS Age, Gender =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = per.sex), ISNULL(CAST((CASE HE.EncounterType WHEN 1 THEN 'Initial Test' WHEN 2 THEN 'Repeat Test' END) AS VARCHAR(50)), 'Initial') AS TestType, clientSelfTestesd =
    (SELECT        TOP 1 CASE [Name] WHEN 'Yes' THEN 'Y' WHEN 'NO' THEN 'N' ELSE NULL END
      FROM            [LookupItem]
      WHERE        [Id] = he.EverSelfTested), StrategyHTS =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = he.TestEntryPoint), ClientTestedAs =
    (SELECT        TOP 1 CASE [Name] WHEN 'C: Couple (includes polygamous)' THEN 'Couple' ELSE 'Individual' END
      FROM            [LookupItem]
      WHERE        [Id] = he.TestedAs), CoupleDiscordant =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = he.CoupleDiscordant), TestedBefore =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = he.evertested), MonthsSinceLastTest WhenLastTested, MaritalStatus =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = ms.maritalstatusid), kits.onekitid AS TestKitName1, kits.onelotnumber AS TestKitLotNumber1, kits.oneexpirydate AS TestKitExpiryDate1, ResultOne =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = her.RoundOneTestResult), kits.twokitid AS TestKitName_2, kits.twolotnumber AS TestKitLotNumber_2, kits.twoexpirydate AS TestKitExpiryDate_2, CASE WHEN dis.[Name] IS NULL 
THEN 'NA' ELSE dis.[Name] END AS Disability, kits.FinalTestOneResult, kits.FinalTestTwoResult AS FinalResultTestTwo, ResultTwo =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = her.RoundTwoTestResult), finalResultHTS =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = her.FinalResult), FinalResultsGiven =
    (SELECT        TOP 1 [Name]
      FROM            [LookupItem]
      WHERE        [Id] = he.FinalResultGiven), /*Disability =  (SELECT TOP 1 [Name] FROM [LookupItem] WHERE [Id] = dis.disabilityid),*/ Consent =
    (SELECT        TOP 1 CASE [Name] WHEN 'Yes' THEN 1 ELSE 0 END
      FROM            [LookupItem]
      WHERE        [Id] =
                                    (SELECT        TOP 1 ConsentValue
                                      FROM            PatientConsent PC
                                      WHERE        PC.PatientMasterVisitId = PM.Id AND PC.ConsentType =
                                                                    (SELECT        TOP 1 [Id]
                                                                      FROM            [lookupItem]
                                                                      WHERE        [Name] = 'ConsentToBeTested'))), he.EncounterRemarks AS Remarks, un.UserName AS TCAHTS, screen.TBScreening AS TBScreeningHTS, 
CASE pop.PopulationCategory WHEN 'General Population' THEN 'N/A' ELSE PopulationCategory END AS KeyPop
FROM            [dbo].[PatientEncounter] PE INNER JOIN
                         patient p ON p.id = pe.patientid INNER JOIN
                         personview per ON per.id = p.personid LEFT JOIN
                         [dbo].[PatientPopulationView] pop ON pop.PatientPK = p.ptn_pk INNER JOIN
                         [dbo].[PatientMasterVisit] PM ON PM.Id = PE.PatientMasterVisitId INNER JOIN
                         [dbo].[HtsEncounter] HE ON PE.Id = HE.PatientEncounterID INNER JOIN
                             (SELECT DISTINCT b.PatientId, d .UserName
                               FROM            dbo.Patient AS a INNER JOIN
                                                         dbo.PatientEncounter AS b ON a.Id = b.PatientId INNER JOIN
                                                         dbo.HtsEncounter AS c ON a.PersonId = c.PersonId INNER JOIN
                                                         dbo.mst_User AS d ON b.CreatedBy = d .UserID) UN ON un.PatientId = pe.PatientId INNER JOIN
                         [dbo].[HtsEncounterResult] HER ON HtsEncounterId = HE.Id LEFT JOIN
                             (SELECT DISTINCT b.PatientId, lv.[ItemName] AS TBScreening
                               FROM            dbo.Patient AS a INNER JOIN
                                                         dbo.PatientEncounter AS b ON a.Id = b.PatientId INNER JOIN
                                                         dbo.HtsEncounter AS c ON a.PersonId = c.PersonId INNER JOIN
                                                         dbo.PatientScreening AS ps ON a.Id = ps.PatientId INNER JOIN
                                                         dbo.[lookupItemView] AS lv ON ps.ScreeningValueId = lv.[ItemId]
                               WHERE        lv.MasterName LIKE '%TbScreening%') screen ON screen.patientid = pe.patientid LEFT JOIN
                         [PatientMaritalStatus] ms ON ms.personid = p.personid LEFT JOIN
                             (SELECT        TOP 1 personid, l.[Name]
                               FROM            [dbo].[ClientDisability] d, [LookupItem] l
                               WHERE        l.[Id] = d .disabilityid) dis ON dis.personid = p.personid LEFT JOIN
                             (SELECT DISTINCT 
                                                         e.personid, one.kitid AS onekitid, one.kitlotnumber AS onelotnumber, one.Outcome AS FinalTestOneResult, two.Outcome AS FinalTestTwoResult, one.expirydate AS oneexpirydate, 
                                                         two.kitid AS twokitid, two.kitlotnumber AS twolotnumber, two.expirydate AS twoexpirydate
                               FROM            [Testing] t INNER JOIN
                                                         [HtsEncounter] e ON t .htsencounterid = e.id LEFT JOIN
                                                         [dbo].[PatientEncounter] pe ON pe.id = e.PatientEncounterID INNER JOIN
                                                         [lookupItem] c ON c.[Id] = pe.EncounterTypeId LEFT OUTER JOIN
                                                             (SELECT DISTINCT htsencounterid, b.[Name] kitid, kitlotnumber, expirydate, PersonId, l.[Name] AS outcome
                                                               FROM            [Testing] t INNER JOIN
                                                                                         [HtsEncounter] e ON t .HtsEncounterId = e.id INNER JOIN
                                                                                         [lookupItem] l ON l.[Id] = t .Outcome INNER JOIN
                                                                                         [lookupItem] b ON b.[Id] = t .KitId INNER JOIN
                                                                                         [dbo].[PatientEncounter] pe ON pe.id = e.PatientEncounterID INNER JOIN
                                                                                         [lookupItem] c ON c.[Id] = pe.EncounterTypeId
                                                               WHERE        e.encountertype = 1 AND t .testround = 1 AND c.[Name] = 'Hts-encounter') one ON one.personid = e.PersonId FULL OUTER JOIN
                                                             (SELECT DISTINCT htsencounterid, b.[Name] kitid, kitlotnumber, expirydate, PersonId, l.[Name] AS outcome
                                                               FROM            [Testing] t INNER JOIN
                                                                                         [HtsEncounter] e ON t .HtsEncounterId = e.id INNER JOIN
                                                                                         [lookupItem] l ON l.[Id] = t .Outcome INNER JOIN
                                                                                         [lookupItem] b ON b.[Id] = t .KitId INNER JOIN
                                                                                         [dbo].[PatientEncounter] pe ON pe.id = e.PatientEncounterID INNER JOIN
                                                                                         [lookupItem] c ON c.[Id] = pe.EncounterTypeId
                                                               WHERE        t .testround = 2 AND c.[Name] = 'Hts-encounter') two ON two.personid = e.PersonId
                               WHERE        c.[Name] = 'Hts-encounter') kits ON kits.personid = p.personid