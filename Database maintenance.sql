-- Incremental Statistics Update for User Databases
EXECUTE dbo.IndexOptimize
    @Databases = 'USER_DATABASES',
    @UpdateStatistics = 'ALL',
    @OnlyModifiedStatistics = 'Y';
GO

-- Intelligent Index Maintenance for User Databases
EXECUTE dbo.IndexOptimize
    @Databases = 'USER_DATABASES',
    @FragmentationLow = NULL,
    @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
    @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
    @FragmentationLevel1 = 5,  -- Reorganize for fragmentation >= 5%
    @FragmentationLevel2 = 30; -- Rebuild for fragmentation >= 30%
GO

-- Full Statistics Update along with Index Maintenance
EXECUTE dbo.IndexOptimize
    @Databases = 'USER_DATABASES',
    @FragmentationLow = NULL,
    @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
    @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
    @FragmentationLevel1 = 5,
    @FragmentationLevel2 = 30,
    @UpdateStatistics = 'ALL',
    @OnlyModifiedStatistics = 'Y';
GO

-- Database Integrity Checks for Very Large Databases (Physical Only)
EXECUTE dbo.DatabaseIntegrityCheck
    @Databases = 'USER_DATABASES',
    @CheckCommands = 'CHECKDB',
    @PhysicalOnly = 'Y';  -- Perform physical integrity check only
GO

-- Smart Differential Backup Based on Modification Level
EXECUTE dbo.DatabaseBackup
    @Databases = 'USER_DATABASES',
    @Directory = 'D:\SQLServerHourBackups',
    @BackupType = 'DIFF',           -- Perform differential backup
    @ChangeBackupType = 'Y',        -- Change to full backup if modification level exceeds threshold
    @ModificationLevel = 50;        -- Switch to full backup if 50% or more of the data has changed
GO

-- Smart Transaction Log Backup Based on Activity
EXECUTE dbo.DatabaseBackup
    @Databases = 'USER_DATABASES',
    @Directory = 'D:\SQLServerHourBackups',
    @BackupType = 'LOG',                -- Perform transaction log backup
    @LogSizeSinceLastLogBackup = 1024,  -- Backup if 1 GB of log has been generated
    @TimeSinceLastLogBackup = 300;      -- Backup if 300 seconds have passed since last backup
GO
