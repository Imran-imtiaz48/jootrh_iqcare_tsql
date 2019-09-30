/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @FromDate AS DateTime = '20170901'
DECLARE @ToDate AS DateTime = Getdate()

SELECT c.IdentifierValue, DATEDIFF(yy,b.DateOfBirth,@ToDate) as AGE
FROM [IQTools].[dbo].[IQC_LastVitals] a
inner join [IQCare_CPAD].[dbo].[Patient] b on a.PatientPK = b.ptn_pk
inner join [IQCare_CPAD].[dbo].PatientIdentifier c on b.Id = c.PatientId
where a.LastVitalsDate between @FromDate and @ToDate  
and b.ptn_pk not in (
select ptn_pk from [IQTools].[dbo].DTL_FBCUSTOMFIELD_Pregnancy_Intention_Assesment
)
order by  AGE  asc