/*the source database should be called IQTools
run the query on the database you want to import the queries into*/

--create the table that holds all the info
Select cat.catID,cat.Category, CR.ReportName,CR.ReportDescription,sbCAT.sbCatID,
  sbCAT.sbCategory,qry.qryID,qry.qryName,qry.qryDefinition,qry.qryDescription,
  qry.qryType,qry.MkTable,qry.qryGroup,xl.xlsCell,xl.xlsTitle,xl.xlCatID,xl.xlsID
INTO imports From IQTools_KEHMIS_BKUP.dbo.aa_Category cat
  Inner Join IQTools_KEHMIS_BKUP.dbo.aa_CustomReports CR On cat.catID = CR.catID
  Inner Join IQTools_KEHMIS_BKUP.dbo.aa_sbCategory sbCAT On cat.catID = sbCAT.catID
  Inner Join IQTools_KEHMIS_BKUP.dbo.aa_Queries qry On sbCAT.QryID = qry.qryID
  Inner Join IQTools_KEHMIS_BKUP.dbo.aa_xlMaps xl On sbCAT.sbCatID = xl.xlCatID
Where CR.ReportName in ('MOH 705B')

  ---Change this 3 according to the report you are working on 
declare @ReportDisplayName varchar(250),
		@ExcelTemplateName varchar(100),
        @ExcelWorksheetName varchar(50)

		set @ReportDisplayName= 'MOH 705B OVER FIVE OUTPATIENT MORBIDITY'
		set @ExcelTemplateName='MOH 705B Template.xlsx'
		set @ExcelWorksheetName='MOH 705B'


UPDATE aa_queries 
SET qryDefinition=S.qryDefinition,qryDescription=S.qryDescription,
qryType=S.qryType,UpdateDate=getDate(),MkTable=S.Mktable,qryGroup=S.QryGroup
FROM aa_queries T JOIN Imports S on S.qryname=T.qryName 


INSERT INTO aa_UserQueries
           ([qryName]
           ,[qryDefinition]
           ,[qryDescription]
           ,[qryType]
           ,[CreateDate]
		   ,[UpdateDate]
           ,[Deleteflag]
           ,[MkTable]
		   ,[Decrypt]
           ,[qryGroup]
		   ,[UID])

		   
SELECT distinct qryName,qryDefinition,[qryDescription],[qryType],getDate(),NULL, 0,mkTable, NULL,'ALL',NULL
FROM imports where not exists(Select * FROM aa_UserQueries qry where qry.qryName=imports.qryName)

--query for categories

INSERT INTO aa_UserCategory
           ([Category]
      ,[UpdateDate]
      ,[CreateDate]
      ,[Deleteflag]
      ,[Excel])
SELECT distinct Category,NULL, getDate(), 0,1
FROM imports where not exists(Select * FROM aa_UserCategory cat where cat.Category=imports.Category)

--query for sub category(review where not exists)
insert into aa_UserSBCategory 
(sbCategory
,catID
,QryId
,createDate
,PSN)
select distinct sbCategory, s.catID, b.qryID, getdate(),s.catID
from Imports JOIN aa_UserQueries b on b.qryName=Imports.qryName
JOIN aa_UserCategory s on s.Category=Imports.Category
where not exists
(Select * FROM aa_UserSBCategory sbc where sbc.qryID=b.qryID AND sbc.sbCategory=imports.sbCategory)


--query for custom report Names

INSERT INTO aa_CustomReports
           ([ReportName]
      ,[ReportDisplayName]
      ,[ReportDescription]
      ,[QueryCategoryID]
      ,[ExcelTemplateName]
      ,[ExcelWorksheetName]
      ,[ReportGroupID])
SELECT distinct ReportName,@ReportDisplayName, Reportdescription,cat.catID, @ExcelTemplateName, @ExcelWorksheetName,1
FROM imports
JOIN aa_UserCategory cat on cat.Category=imports.category
 where not exists
(Select * FROM aa_CustomReports rpt where rpt.ReportName=imports.ReportName)

-- Query for aa_ReportParameters

INSERT INTO [dbo].[aa_ReportParameters]
           ([ReportID]
           ,[ParamName]
           ,[ParamLabel]
           ,[ParamType]
           ,[ParamDefaultValue]
           ,[Position]
           ,[CreateDate]
           ,[UpdateDate]
           ,[DeleteFlag])
SELECT distinct a.ReportID,'iqtDatehelper','Select Register Period','datehelper','Monthly',1, getdate(), NULL, NULL
FROM aa_CustomReports a
JOIN aa_UserCategory cat on cat.CatID=a.QueryCategoryID
 where not exists
(Select * FROM [aa_ReportParameters] rpt where rpt.ReportID=a.ReportID)


--query for xl maps

UPDATE aa_UserXLMaps
SET qryID=S.qryID,xlsTitle=S.xlsTitle,createDate=getDate()
FROM aa_UserXLMaps T JOIN Imports S on S.xlsCell=T.xlsCell
JOIN aa_UserSBCategory sb on T.xlCatID=sb.sbCatID


insert into aa_UserXLMaps
(xlsCell,qryId,xlsTitle,CreateDate,xlCatID)
select distinct
imports.xlsCell
, Q.qryID
, imports.xlsTitle
, getdate()
, sb.sbCatID
from Imports
inner join aa_UserQueries Q on q.qryName=imports.qryName
inner join aa_UserSBCategory sb on imports.sbcategory = sb.sbCategory 
and q.qryId=sb.qryID


where not exists
(Select * FROM aa_UserXLMaps maps where imports.xlsCell=maps.xlsCell
and maps.xlCatID=sb.sbCatID)

