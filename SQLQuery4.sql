Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw=='
GO

SELECT 
ptn_pk,
PersonId,
c.IdentifierValue as PatientID,
c.IdentifierOld as PatientIDOld,
CONVERT(varchar(50), DecryptByKey(B.FirstName)) AS 'FirstName',
CONVERT(varchar(50), DecryptByKey(B.LastName)) AS 'LastName',
f.Name as PatientType,
m.Name as Sex,
DATEDIFF(yy,A.DateofBirth,A.RegistrationDate) AS RegistrationAge,
DATEDIFF(yy,A.DateofBirth,GETDATE()) AS currentAge,
RegistrationDate,
Z.VisitDate,
P.NextAppointmentDate  

FROM [IQCare_CPAD].[dbo].[Patient] A
  inner Join (SELECT PatientId, MAX(CreateDate) as VisitDate
      FROM [IQCare_CPAD].[dbo].[PatientMasterVisit]
	  group by PatientId) Z on A.Id = z.PatientId
  inner join [IQCare_CPAD].[dbo].[LookupItem] f on A.PatientType = f.Id
  inner join [IQCare_CPAD].[dbo].[PatientIdentifier] c on a.Id = c.PatientId
  inner join [IQCare_CPAD].[dbo].[Person] b on a.PersonId = b.Id
  inner join [IQCare_CPAD].[dbo].[LookupItem] m on b.Sex = m.Id
  left JOIN (Select Y.ptn_pk AS PatientPK, MAX(AppointmentDate) as NextAppointmentDate  FROM [IQCare_CPAD].[dbo].[PatientAppointment] X
  Inner join [IQCare_CPAD].[dbo].[Patient] Y on X.PatientId = Y.Id
  group by Y.ptn_pk) P on A.ptn_pk = p.PatientPK
  where A.Id not in (SELECT PatientId FROM [IQCare_CPAD].[dbo].[PatientCareending]) and P.NextAppointmentDate is not null and VisitDate < '2017-10-31'
  order by B.FirstName asc

