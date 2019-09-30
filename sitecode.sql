SELECT DISTINCT
 *,
LEFT([Gender],1)+[sxFirstName]+[sxLastName]+LTRIM(RTRIM(STR(YEAR(X.DOB)))) AS [sxPKValue],
LEFT([Gender],1)+
    CASE
    WHEN CHARINDEX(';',[dmFirstName])>0 THEN
       SUBSTRING([dmFirstName],CHARINDEX(';',[dmFirstName])+1,LEN([dmFirstName]))
    ELSE
     [dmFirstName]
    END +
    CASE
    WHEN CHARINDEX(';',[dmLastName])>0 THEN
       SUBSTRING([dmLastName],CHARINDEX(';',[dmLastName])+1,LEN([dmLastName]))
    ELSE
     [dmLastName]
    END +LTRIM(RTRIM(STR(YEAR(DOB)))) AS [dmPKValue],
CASE WHEN CHARINDEX(';',[dmLastName])>0 THEN
     LEFT([Gender],1)+ [sxFirstName]+ SUBSTRING([dmLastName],CHARINDEX(';',[dmLastName])+1,LEN([dmLastName]))+LTRIM(RTRIM(STR(YEAR(DOB))))
    ELSE
     LEFT([Gender],1)+ [sxFirstName]+[dmLastName]+LTRIM(RTRIM(STR(YEAR(DOB))))
    END AS [sxdmPKValue],
LEFT([Gender],1)+[sxFirstName]+[sxLastName]+LTRIM(RTRIM(STR(CONVERT(VARCHAR(20),DOB,112)))) AS [sxPKValueDoB],
LEFT([Gender],1)+
    CASE
    WHEN CHARINDEX(';',[dmFirstName])>0 THEN
       SUBSTRING([dmFirstName],CHARINDEX(';',[dmFirstName])+1,LEN([dmFirstName]))
    ELSE
     [dmFirstName]
    END +
    CASE
    WHEN CHARINDEX(';',[dmLastName])>0 THEN
       SUBSTRING([dmLastName],CHARINDEX(';',[dmLastName])+1,LEN([dmLastName]))
    ELSE
     [dmLastName]
    END +LTRIM(RTRIM(STR(CONVERT(VARCHAR(20),DOB,112)))) AS [dmPKValueDoB],
CASE WHEN CHARINDEX(';',[dmLastName])>0 THEN
     LEFT([Gender],1)+ [sxFirstName]+ SUBSTRING([dmLastName],CHARINDEX(';',[dmLastName])+1,LEN([dmLastName]))+LTRIM(RTRIM(STR(CONVERT(VARCHAR(20),DOB,112))))
    ELSE
     LEFT([Gender],1)+ [sxFirstName]+[dmLastName]+LTRIM(RTRIM(STR(CONVERT(VARCHAR(20),DOB,112))))
    END AS [sxdmPKValueDoB]

FROM
(
SELECT
   -------Demographics
   Ptn_Pk,a.PatientPK,a.SiteCode,a.FacilityName,
    case when a.HTSID is null then a.PatientID else a.HTSID end as Serial

      ,UPPER([dFirstName]) FirstName
   ,UPPER([dMiddleName]) MiddleName
      ,UPPER([dLastName]) LastName
   ,dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dFirstName],'0','O'))) AS [FirstName_Normalized]
      ,dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dMiddleName],'0','O'))) AS [MiddleName_Normalized]
      ,dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dLastName],'0','O'))) AS [LastName_Normalized]
     ,SOUNDEX(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dFirstName],'0','O')))) AS  [sxFirstName]
   ,SOUNDEX(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dLastName],'0','O')))) AS [sxLastName]
   ,SOUNDEX(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dMiddleName],'0','O')))) AS sxMiddleName
  ,[dmFirstName]= dbo.fn_getPatientNameDoubleMetaphone(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dFirstName],'0','O'))))
  ,[dmLastName] = dbo.fn_getPatientNameDoubleMetaphone(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dLastName],'0','O'))))
  ,dmMiddleName = dbo.fn_getPatientNameDoubleMetaphone(dbo.[fnReplaceInvalidChars](UPPER(REPLACE([dMiddleName],'0','O'))))
  ,a.[PhoneNumber]PatientPhoneNumber
   ,NULL PatientAlternatePhoneNumber
      ,a.[Gender]
      ,a.[DOB]
   ,a.[MaritalStatus]
   -------Patient Address
   ,a.[PatientSource]
      ,[Region]PatientCounty
      ,[District]PatientSubCounty
      ,[Village]PatientVillage
   -------Patient-Identifiers
   ,mst.[PatientClinicID]PatientID
   ,[NationalId][National_ID]
   ,NULL as [NHIF_Number]
   ,NULL as [Birth_Certificate]
   ,b.[PatientID][CCC_Number]
   ,ltrim(rtrim(DistrictRegistrationNr))[TB_Number]
      -------Next Of Kin
   
      ,LTRIM(RTRIM(ContactName)) AS ContactName
      ,[ContactRelation] AS  ContactRelation
      ,[ContactPhoneNumber] as ContactPhoneNumber
      ,[ContactAddress] as ContactAddress
   , NULL AS  NokNationalId
   -------Additional Variables
      ,[DateConfirmedHIVPositive]
   ,b.[StartARTDate]
   ,[StartRegimen]StartARTRegimenCode
   ,[StartRegimenLine]StartARTRegimenDesc
  
  FROM [dbo].[tmp_PatientMaster] a
  inner join [dbo].[mst_patient_decoded]mst on a.patientpk=mst.ptn_pk
  left  join (SELECT DISTINCT a.PatientPK, a.PatientID, a.RegistrationAtCCC, b.StartARTDate, b.StartRegimen, b.StartRegimenLine
  FROM
  tmp_PatientMaster AS a LEFT OUTER JOIN dbo.tmp_ARTPatients AS b ON a.PatientPK = b.PatientPK
  WHERE  (a.RegistrationAtCCC IS NOT NULL)) b on a.patientpk=b.patientpk
  Where len(a.htsid) > 0 or len(a.PatientID) > 0
 --ORDER BY PKV_2,Ptn_Pk  ASC
) X
INNER JOIN
(
SELECT
  Ptn_Pk,
    case when a.HTSID is null then a.PatientID else a.HTSID end as Serial
FROM [dbo].[tmp_PatientMaster] a
  inner join [dbo].[mst_patient_decoded]mst on a.patientpk=mst.ptn_pk
  left  join (SELECT DISTINCT a.PatientPK, a.PatientID, a.RegistrationAtCCC, b.StartARTDate, b.StartRegimen, b.StartRegimenLine
  FROM dbo.tmp_PatientMaster AS a LEFT OUTER JOIN dbo.tmp_ARTPatients AS b ON a.PatientPK = b.PatientPK
  WHERE  (a.RegistrationAtCCC IS NOT NULL)) b on a.patientpk=b.patientpk
  Where len(a.htsid) > 0 or len(a.PatientID) > 0 

)Y
ON
Y.Ptn_Pk = X.Ptn_Pk AND Y.Serial= X.Serial