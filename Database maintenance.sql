--Incremental Statistics
EXECUTE dbo.IndexOptimize
@Databases = 'USER_DATABASES',
@UpdateStatistics = 'ALL',
@OnlyModifiedStatistics = 'Y'


--Intelligent Index Maintenance
EXECUTE dbo.IndexOptimize @Databases = 'USER_DATABASES',
@FragmentationLow = NULL,
@FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationLevel1 = 5,
@FragmentationLevel2 = 30

--Update Statistics
EXECUTE dbo.IndexOptimize @Databases = 'USER_DATABASES',
@FragmentationLow = NULL,
@FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationLevel1 = 5,
@FragmentationLevel2 = 30,
@UpdateStatistics = 'ALL',
@OnlyModifiedStatistics = 'Y'

--Run Integrity Checks of Very Large Databases
EXECUTE dbo.DatabaseIntegrityCheck
@Databases = 'USER_DATABASES',
@CheckCommands = 'CHECKDB',
@PhysicalOnly = 'Y'


--SQL Server Smart Differential and Transaction Log Backup
--Here's how it can be used to perform a differential backup if less than 50% of the database has been modified, and a full backup if 50% or more of the database has been modified.
EXECUTE dbo.DatabaseBackup
@Databases = 'USER_DATABASES',
@Directory = 'D:\SQLServerHourBackups',
@BackupType = 'DIFF',
@ChangeBackupType = 'Y',
@ModificationLevel = 50

--Here's how it can be used to perform a transaction log backup if 1 GB of log has been generated since the last log backup, or if it has not been backed up for 300 seconds. This enables you to do more frequent log backups of databases with high activity, and in periods of high activity.
EXECUTE dbo.DatabaseBackup
@Databases = 'USER_DATABASES',
@Directory = 'D:\SQLServerHourBackups',
@BackupType = 'LOG',
@LogSizeSinceLastLogBackup = 1024,
@TimeSinceLastLogBackup = 300