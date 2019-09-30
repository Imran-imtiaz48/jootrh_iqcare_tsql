select Abbreviation, * from mst_drug WHERE Abbreviation LIKE '%efv/3tc/tdf%'


update Mst_ItemMaster SET Abbreviation = CONCAT(Abbreviation, ' TLD') WHERE Item_Pk = 1678


select abbreviation, * from Mst_ItemMaster WHERE Item_PK = 1705

update Mst_ItemMaster SET Abbreviation = 'TDF/3TC/EFV TLE600' WHERE Item_Pk = 1163


select abbreviation,* from Mst_ItemMaster WHERE abbreviation LIKE '%DTG%' AND DeleteFlag = 0 order by item_pk desc

update Mst_ItemMaster SET abbreviation ='TDF/3TF/DTG TLD', ItemName = 'Tenofovir DF/Lamivudine/Dolutegravir-TDF300mg/3TC300mg/DTG50mg TLD 300mg/300mg/50mg'  WHERE Item_PK = 1704



update Mst_ItemMaster SET DeleteFlag = 1 WHERE Item_PK IN (1146,1149,114,11667)

--delete from Mst_ItemMaster WHERE Item_PK = 1701


select * from mst_strength WHERE StrengthName LIKE '400%' order by StrengthId desc

-- delete from mst_Strength WHERE StrengthId = 337

select * from lnk_DrugStrength order by CreateDate DESC

update lnk_DrugStrength SET StrengthId = 8 WHERE StrengthId = 337 AND DrugId =1705

select * from strengtn



select * from Mst_ItemMaster WHERE abbreviation LIKE '%D4T%'AND DeleteFlag = 1


UPDATE Mst_ItemMaster SET DeleteFlag = 0 WHERE abbreviation LIKE '%D4T%';


select * from 
