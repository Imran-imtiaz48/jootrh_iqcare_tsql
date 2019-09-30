/*============================================================================
  File:     Index - Rarely Used Indexes

  Summary:  Sample stored procedure that lists rarely-used indexes. Because the number and type of accesses are 
		tracked in dmvs, this procedure can find indexes that are rarely useful. Because the cost of these indexes 
		is incurred during maintenance (e.g. insert, update, and delete operations), the write costs of rarely-used 
		indexes may outweigh the benefits.

		sp_help tblPasswordHistory
		sp_helptext fnt_currency_user
		select top 10 * from tblPasswordHistory
  
  Date:     2008

  Versions: 2005, 2008, 2012
------------------------------------------------------------------------------
  Written by Ben DeBow, SQLHA
	
  For more scripts and sample code, check out 
    http://www.SQLHA.com

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

/* Create a temporary table to hold our data, since we're going to iterate through databases */
IF OBJECT_ID('tempdb..#Results') IS NOT NULL
    DROP TABLE #Results;
 
CREATE TABLE [dbo].#Results(
	[Server Name] [nvarchar](128) NULL,
	[DB Name] [nvarchar](128) NULL,
	[source] [varchar](10) NOT NULL,
	[objectname] [nvarchar](128) NULL,
	[object_id] [int] NOT NULL,
	[indexname] [sysname] NULL,
	[data_compression] [varchar](24) NOT NULL,
	[index_id] [int] NOT NULL,
	[rowcnt] [bigint] NULL,
	[datapages] [bigint] NULL,
	[is_unique] [bit] NULL,
	[count] [int] NULL,
	[user_seeks] [bigint] NOT NULL,
	[user_scans] [bigint] NOT NULL,
	[user_lookups] [bigint] NOT NULL,
	[user_updates] [bigint] NOT NULL,
	[total_usage] [bigint] NOT NULL,
	[%Reads] [bigint] NULL,
	[%Writes] [bigint] NULL,
	[%Seeks] [bigint] NULL,
	[%Scans] [bigint] NULL,
	[%Lookups] [bigint] NULL,
	[%Updates] [bigint] NULL,
	[last_user_scan] [datetime] NULL,
	[last_user_seek] [datetime] NULL,
	[run_time] [datetime] NOT NULL
) ON [PRIMARY]
EXECUTE sys.sp_MSforeachdb
	'USE [?]; 
	declare @dbid int
	select @dbid = db_id()
INSERT INTO #Results
SELECT @@SERVERNAME AS [Server Name] 
	, db_name() AS [DB Name]
	, ''Usage Data'' ''source''
	, objectname=object_name(s.object_id)
	, s.object_id, indexname=i.name
	, data_compression_desc, i.index_id
	, s2.rowcnt, sa.total_pages, is_unique
	, (select count(*)
		from sys.indexes r 
		where r.object_id = s.object_id) ''count''
	, user_seeks, user_scans, user_lookups, user_updates, user_seeks + user_scans + user_lookups + user_updates AS [total_usage]
	, CAST(CAST(user_seeks + user_scans + user_lookups AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Reads]
	, CAST(CAST(user_updates AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Writes]
	, CAST(CAST(user_seeks AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Seeks]
	, CAST(CAST(user_scans AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Scans]
	, CAST(CAST(user_lookups AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Lookups]
	, CAST(CAST(user_updates AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [%Updates]
	, last_user_scan
	, last_user_seek
	, getdate() run_time
from sys.dm_db_index_usage_stats s
join sys.indexes i on i.object_id = s.object_id
	and i.index_id = s.index_id
join sysindexes s2 on i.object_id = s2.id
	and i.index_id = s2.indid
join sys.partitions sp on i.object_id = sp.object_id
	and i.index_id = sp.index_id
join sys.allocation_units sa on sa.container_id = sp.hobt_id
where objectproperty(s.object_id, ''IsUserTable'') = 1
and database_id = @dbid'

EXECUTE sys.sp_MSforeachdb
	'USE [?]; 

	declare @dbid int
	
	select @dbid = db_id()

INSERT INTO #Results
SELECT @@SERVERNAME
	, db_name()
	, ''NA''  
	, object_name(i.object_id)
	, o.object_id
	, i.name
	, data_compression_desc
	, i.index_id
	, s2.rowcnt
	, sa.total_pages
	, is_unique
	, (select count(*)
		from sys.indexes r 
		where r.object_id = i.object_id) ''count''
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, getdate()
FROM sys.indexes i
JOIN sys.objects o
	ON i.object_id = o.object_id
join sysindexes s2 on i.object_id = s2.id
	and i.index_id = s2.indid
join sys.partitions sp on i.object_id = sp.object_id
	and i.index_id = sp.index_id
join sys.allocation_units sa on sa.container_id = sp.hobt_id
WHERE OBJECTPROPERTY(o.object_id,''IsUserTable'') = 1
    AND i.index_id NOT IN (
	SELECT s.index_id
    FROM sys.dm_db_index_usage_stats s
    WHERE  s.object_id = i.object_id
        AND i.index_id = s.index_id
        AND database_id = @dbid)
--AND i.index_id NOT IN (0,1)'

SELECT *
FROM #Results
WHERE [DB Name] NOT IN ('MASTER', 'msdb', 'MODEL', 'TEMPDB')

DROP TABLE #Results;

/*
	declare @dbid int

	select @dbid = db_id()

SELECT @@SERVERNAME AS [Server Name] 
	, db_name() AS [DB Name]
	, 'Usage Data' 'source'
	, objectname=object_name(s.object_id)
	, s.object_id
	, indexname=i.name
	, data_compression_desc
	, i.index_id
	, s2.rowcnt
	, sa.total_pages
	, is_unique
	, (select count(*)
		from sys.indexes r 
		where r.object_id = s.object_id) 'count'
	, user_seeks
	, user_scans
	, user_lookups
	, user_updates
	, user_seeks + user_scans + user_lookups + user_updates AS [total_usage]
	, CAST(CAST(user_seeks AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [% Seeks]
	, CAST(CAST(user_scans AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [% Scans]
	, CAST(CAST(user_lookups AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [% Lookups]
	, CAST(CAST(user_updates AS DEC(12,2))/CAST(REPLACE((user_seeks + user_scans + user_lookups + user_updates), 0, 1) AS DEC(12,2)) * 100 AS DEC(5,2)) [% Updates]
	, last_user_scan
	, last_user_seek
	, getdate() run_time
from sys.dm_db_index_usage_stats s
join sys.indexes i on i.object_id = s.object_id
	and i.index_id = s.index_id
join sysindexes s2 on i.object_id = s2.id
	and i.index_id = s2.indid
join sys.partitions sp on i.object_id = sp.object_id
	and i.index_id = sp.index_id
join sys.allocation_units sa on sa.container_id = sp.hobt_id
where objectproperty(s.object_id, 'IsUserTable') = 1
and database_id = @dbid 
--and 'etblHistory' = object_name(s.object_id)
UNION ALL
SELECT @@SERVERNAME AS [Server Name] 
	, db_name() AS [DB Name]
	, 'NA'  
	, objectname = object_name(o.object_id)
	, o.object_id
	, indexname = i.name
	, i.index_id
	, s2.rowcnt
	, sa.total_pages
	, is_unique
	, data_compression_desc
	, (select count(*)
		from sys.indexes r 
		where r.object_id = i.object_id) 'count'
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, 0
	, getdate() run_time
FROM sys.indexes i
JOIN sys.objects o
	ON i.object_id = o.object_id
join sysindexes s2 on i.object_id = s2.id
	and i.index_id = s2.indid
join sys.partitions sp on i.object_id = sp.object_id
	and i.index_id = sp.index_id
join sys.allocation_units sa on sa.container_id = sp.hobt_id
WHERE OBJECTPROPERTY(o.object_id,'IsUserTable') = 1
    AND i.index_id NOT IN (
	SELECT s.index_id
    FROM sys.dm_db_index_usage_stats s
    WHERE  s.object_id = i.object_id
        AND i.index_id = s.index_id
        AND database_id = @dbid)
--AND i.index_id NOT IN (0,1)
order by last_user_scan, last_user_seek
*/