SELECT DISTINCT 
                         pt.Id, pt.PersonId, pt.ptn_pk, pni.IdentifierValue AS EnrollmentNumber, pt.PatientIndex, CAST(DECRYPTBYKEY(pn.FirstName) AS VARCHAR(50)) AS FirstName, CAST(DECRYPTBYKEY(pn.MidName) 
                         AS VARCHAR(50)) AS MiddleName, CAST(DECRYPTBYKEY(pn.LastName) AS VARCHAR(50)) AS LastName, pn.Sex, pn.Active, pt.RegistrationDate, pe.EnrollmentDate AS [EnrollmentDate ], 
                         ISNULL(CAST((CASE pe.CareEnded WHEN 0 THEN 'Active' WHEN 1 THEN
                             (SELECT        TOP 1 ItemName
                               FROM            LookupItemView
                               WHERE        MasterName = 'CareEnded' AND ItemId = ptC.ExitReason) END) AS VARCHAR(50)), 'Active') AS PatientStatus, ptC.ExitReason, pt.DateOfBirth, CAST(DECRYPTBYKEY(pt.NationalId) AS VARCHAR(50)) 
                         AS NationalId, pt.FacilityId, pt.PatientType, pe.TransferIn, CAST(DECRYPTBYKEY(pc.MobileNumber) AS VARCHAR(20)) AS MobileNumber, ISNULL
                             ((SELECT        TOP (1) ScreeningValueId
                                 FROM            dbo.PatientScreening
                                 WHERE        (PatientId = pt.Id) AND (ScreeningTypeId IN
                                                              (SELECT        Id
                                                                FROM            dbo.LookupMaster
                                                                WHERE        (Name = 'TBStatus')))
                                 ORDER BY Id DESC), 0) AS TBStatus, ISNULL
                             ((SELECT        TOP (1) ScreeningValueId
                                 FROM            dbo.PatientScreening AS PatientScreening_1
                                 WHERE        (PatientId = pt.Id) AND (ScreeningTypeId IN
                                                              (SELECT        Id
                                                                FROM            dbo.LookupMaster AS LookupMaster_1
                                                                WHERE        (Name = 'NutritionStatus')))
                                 ORDER BY Id DESC), 0) AS NutritionStatus, ISNULL
                             ((SELECT        TOP (1) Categorization
                                 FROM            dbo.PatientCategorization
                                 WHERE        (PatientId = pt.Id)
                                 ORDER BY id DESC), 0) AS Categorization, pt.DobPrecision
FROM            dbo.Patient AS pt INNER JOIN
                         dbo.Person AS pn ON pn.Id = pt.PersonId INNER JOIN
                         dbo.PatientEnrollment AS pe ON pt.Id = pe.PatientId INNER JOIN
                         dbo.PatientIdentifier AS pni ON pni.PatientId = pt.Id INNER JOIN
                         dbo.Identifiers ON pni.IdentifierTypeId = dbo.Identifiers.Id LEFT OUTER JOIN
                         dbo.PatientCareending AS ptC ON pt.Id = ptC.PatientId LEFT OUTER JOIN
                         dbo.PersonContact AS pc ON pc.PersonId = pt.PersonId
WHERE        (dbo.Identifiers.Name = 'CCC Registration Number') AND (pn.DeleteFlag = 0)