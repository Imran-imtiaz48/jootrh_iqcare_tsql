
ALTER DATABASE [IQCare_CPAD]
SET MULTI_USER
WITH ROLLBACK IMMEDIATE
GO
USE [IQCare_CPAD];
GO
DBCC SHRINKFILE (TestDatabase_IQCare_log, 3000);
GO



USE [IQCare_CPAD];  
GO  
-- Truncate the log by changing the database recovery model to SIMPLE.  
ALTER DATABASE [IQCare_CPAD]  
SET RECOVERY SIMPLE;  
GO  
-- Shrink the truncated log file to 1 MB.  
DBCC SHRINKFILE (TestDatabase_IQCare_Log, 3048);  
GO  
-- Reset the database recovery model.  
ALTER DATABASE [IQCare_CPAD]  
SET RECOVERY FULL;  
GO  


s