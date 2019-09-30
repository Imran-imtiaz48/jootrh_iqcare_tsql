SELECT        
mst_Patient.OTZNumber,
mst_Patient.PatientEnrollmentID,
DATEDIFF(YEAR,mst_Patient.DOB,GETDATE()) AS Age, 
Sex.Name AS Sex,
Education.Name AS Education, Occupation.Name AS Occupation, TypeOfSchool.Name AS TypeOfSchool, TypeOfIncome.Name AS TypeOFincome, HaveFather.Name AS FatherAlive, 
                         HaveMOther.Name AS MotherAlive, HaveGuardian.Name AS HasGuardian, SpecifyRel.Name AS SpecifyRelatonship, LiveWith.Name AS LiveWith, FinancialSupporter.Name AS FinancialSupporter, 
                         SupportAnyoneFin.Name AS SupportAnyoneFin, pa.ResidenceCounty, pa.ResidenceEstate, HavePartner.Name AS HavePartner, StartedIntercourse.Name AS StartedSexualIntercourse,  
						 SexualPartners = STUFF((
										  SELECT ',' + d.Name
										  FROM dtl_FB_SexualPartners sp
										  INNER JOIN mst_ModDeCode d ON sp.SexualPartners =d.ID 
										  WHERE sp.Visit_Pk = pa.Visit_Pk
										  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
                         UseCondoms.Name AS UseCondoms, 
						 SexForMoney.Name AS EverHadSexForMoney, EverPregnant.Name AS EverBeenPregnant, pa.Pregnancies AS TimesPregnant, 
                         LastPregOutcome.Name AS LastPregancyOutcome, 
--						 ContraceptionMethod.Name AS OnContraception, 
						 ContraceptionsInUse = STUFF((
										  SELECT ',' + d.Name
										  FROM dtl_FB_ContraceptionsInUse ct
										  INNER JOIN mst_ModDeCode d ON ct.ContraceptionsInUse =d.ID 
										  WHERE ct.Visit_Pk = pa.Visit_Pk
										  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),						 						 
						 DisclosedHIVStatus.Name AS EverDisclosedHIVStatus, pa.DisclosedTo, 
                         EverSmoke.Name AS Smokes, EverAlcohol.Name AS DrinksAlcohol,  
                         ISNULL(EverHadCaCxScreen.Name,EverHadCervicalCancerScreening.Name) AS CervicalCancerScreening, pa.CaCxScreenDate AS CervicalCancerScreeningDate, EverSmoke.Name AS Smokes, EverAlcohol.Name AS DrinksAlcohol, 
                         OtherSubstance.Name AS OtherSubstance, EverSexuallyAbused.Name AS EVerSexuallyAbused, pa.SexualAbuseAssailant, EverPhysicallyAbused.Name AS PhysicallyAbused, 
                         EverEmotionallyAbused.Name AS EMotionallyAbused, EverTreatedSTI.Name AS EverTreatedForSti, pa.CommentToManagement, pa.OtherComments, CAST(pa.CreateDate AS DATE) AS [Date Created]
FROM            DTL_FBCUSTOMFIELD_Adolescent_Followup_Psychosocial_Assessment AS pa INNER JOIN
                         mst_Patient ON pa.Ptn_pk = mst_Patient.Ptn_Pk INNER JOIN
						 mst_DeCode sex ON sex.ID = mst_Patient.Sex LEFT OUTER JOIN  
                         mst_ModDeCode AS Education ON pa.Education = Education.ID LEFT OUTER JOIN
                         mst_ModDeCode AS Occupation ON pa.Occupation = Occupation.ID LEFT OUTER JOIN
                         mst_ModDeCode AS TypeOfSchool ON pa.TypeOfSchool = TypeOfSchool.ID LEFT OUTER JOIN
                         mst_ModDeCode AS TypeOfIncome ON pa.OTZTypeOfIncome = TypeOfIncome.ID LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS HaveFather ON pa.HaveFather = HaveFather.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS HaveMOther ON pa.HaveMother = HaveMOther.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS HaveGuardian ON pa.HaveGuardian = HaveGuardian.Id LEFT OUTER JOIN
                         mst_ModDeCode AS SpecifyRel ON pa.OTZRelationshipType = SpecifyRel.ID LEFT OUTER JOIN
                         mst_ModDeCode AS LiveWith ON pa.LiveWith = LiveWith.ID LEFT OUTER JOIN
                         mst_ModDeCode AS FinancialSupporter ON pa.FinancialSupporter = FinancialSupporter.ID LEFT OUTER JOIN
                         mst_ModDeCode AS SupportAnyoneFin ON pa.SupportAnyoneFin = SupportAnyoneFin.ID LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS HavePartner ON pa.HavePartner = HavePartner.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS StartedIntercourse ON pa.StartedSexualIntercourse = StartedIntercourse.Id LEFT OUTER JOIN
                         mst_ModDeCode AS UseCondoms ON (CASE pa.UseCondom WHEN 1 THEN 1639 ELSE pa.UseCondom END) = UseCondoms.Id LEFT OUTER JOIN
--						 dtl_FB_SexualPartners sexpartner ON pa.Ptn_pk = sexpartner.Ptn_pk and pa.Visit_Pk = sexpartner.Visit_Pk LEFT OUTER JOIN 
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS SexForMoney ON pa.EverHadSexForMoney = SexForMoney.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverPregnant ON pa.EverBeenPregnant = EverPregnant.Id LEFT OUTER JOIN
                         mst_ModDeCode AS LastPregOutcome ON pa.LastPregnancyOutcome = LastPregOutcome.ID LEFT OUTER JOIN
                         mst_ModDeCode AS ContraceptionMethod ON pa.ContraceptMethods = ContraceptionMethod.ID LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS DisclosedHIVStatus ON pa.HIVStatusDisclosure = DisclosedHIVStatus.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverHadCaCxScreen ON pa.EverHadCaCxScreen = EverHadCaCxScreen.Id LEFT OUTER JOIN
                         mst_ModDeCode AS EverHadCervicalCancerScreening ON pa.EverHadCervicalCancerScreening = EverHadCervicalCancerScreening.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverSmoke ON pa.Smoke = EverSmoke.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverAlcohol ON pa.Alcohol = EverAlcohol.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS OtherSubstance ON pa.OtherSubstance = OtherSubstance.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverSexuallyAbused ON pa.SexuallyAbused = EverSexuallyAbused.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverPhysicallyAbused ON pa.PhysicallyAbused = EverPhysicallyAbused.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverEmotionallyAbused ON pa.EmotionallyAbused = EverEmotionallyAbused.Id LEFT OUTER JOIN
                         (SELECT CASE id WHEN 2 THEN 0 WHEN 1 THEN 1 END AS ID, Name FROM mst_YesNo) AS EverTreatedSTI ON pa.TreatedForSTI = EverTreatedSTI.Id
						 WHERE pa.UserId > 1 -- and (UseCondom is not null or ContraceptMethods IS NOT NULL)

/*

SELECT * FROM mst_Feature WHERE FeatureName LIKE '%Adolescent Followup Psychosocial Assessment%'

SELECT * FROM mst_Section WHERE FeatureId = 1098
SELECT * FROM FormFieldsView where featureId = 1098

select * from Mst_YesNo

select * from mst_customformfield where id = 1227

SELECT FieldId,FieldLabel,FieldName,BindTable,SectionName,SectionOrder,fieldOrder FROM FormFieldsView WHERE SectionId in (390,391) ORDER BY SectionName



*/