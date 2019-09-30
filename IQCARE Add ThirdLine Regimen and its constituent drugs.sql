-- Add third line regimen RAL+DRV+RTV+TDF+3TC and its constituent drugs
UPDATE LookupItem SET DisplayName = 'RAL+DRV+RTV+TDF+3TC' WHERE [Name] = 'AT1F'
UPDATE Mst_ItemMaster SET abbreviation = 'RAL' WHERE Item_PK = 1688
UPDATE Mst_ItemMaster SET abbreviation = 'DRV/RTV' WHERE Item_PK = 1689


SELECT abbreviation,DeleteFlag,* FROM Mst_ItemMaster 
-- WHERE ItemName LIKE '%Raltegravir%'
ORDER BY CreateDate DESC
