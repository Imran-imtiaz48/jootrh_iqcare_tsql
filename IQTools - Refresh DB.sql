USE [IQTools_KeHMIS]
GO
/****** Object:  StoredProcedure [dbo].[pr_RefreshIQTools]    Script Date: 7/6/2019 11:44:11 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER Procedure [dbo].[pr_RefreshIQTools]
 (@FacilityName varchar(50)
 , @EMR varchar(10)
 , @EMRVersion varchar(10)
 , @PatientPK int = 0
 , @VisitPK int = 0 
 , @RefreshFlag int = 0) AS

BEGIN
IF(@EMR = 'iqcare')
 BEGIN

  declare @iqcare_db varchar(50), @iqtools_db varchar(50), @query varchar(max), @query1 varchar(max);
  Select @iqtools_db = db_name();
  Select top 1 @iqcare_db= dbase from aa_Database;
  IF EXISTS(Select Name FROM sys.tables WHERE Name = N'mst_patient_decoded') 
	 DROP TABLE mst_patient_decoded
		
	  Select @query = 'exec '+@iqcare_db+'.dbo.pr_OpenDecryptedSession
	 Select a.*,  convert(varchar(100),pv.MiddleName) dMiddleName, convert(varchar(100),pv.firstname) dFirstName, 
	  convert(varchar(100),pv.LastName)dLastName, convert(varchar(100),pv.Address)dAddress, convert(varchar(100),pv.Phone) dPhone, 
	  convert(varchar(100),b.NationalId) dNationalId, convert(varchar(100),c.EmergContactName) dContactName, convert(varchar(100),c.EmergContactPhone) dContactPhone,
	   convert(varchar(100),c.EmergContactAddress) dContactAddress  INTO '+@iqtools_db+'.dbo.mst_patient_decoded 
	   From '+@iqcare_db+'.dbo.mst_patient a left outer join '+@iqcare_db+'.dbo.patient b on a.ptn_pk=b.ptn_pk inner join '+@iqcare_db+'.dbo.PatientView pv 
	   on pv.Ptn_Pk=a.Ptn_Pk left join 
		(Select c.ptn_pk, Max(c.EmergContactRelation) EmergContactRelation, cast(Max(c.EmergContactName) as nvarchar(100)) EmergContactName, 
		Max(c.EmergContactPhone) EmergContactPhone, Max(c.EmergContactAddress) EmergContactAddress From
		(Select c.ptn_pk, Max(c.EmergContactRelation) EmergContactRelation, cast(Max(c.EmergContactName) as nvarchar(100)) EmergContactName, 
		Max(c.EmergContactPhone) EmergContactPhone, Max(c.EmergContactAddress) EmergContactAddress From '+@iqcare_db+'.dbo.dtl_patientcontacts c
		Group By c.ptn_pk )c  group by ptn_pk)c on a.ptn_pk = c.ptn_pk  Where a.deleteflag is null or a.deleteflag=0

	  exec '+@iqcare_db+'.dbo.pr_CloseDecryptedSession'

  exec(@query)

 

 IF EXISTS(select name from sys.synonyms where name = 'DTL_FBCUSTOMFIELD_01_Initial_Evaluation_Form')
 BEGIN
---- Drop the IQTools Tables
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_PatientMaster') AND type in ('U'))
  DROP TABLE tmp_PatientMaster
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_ANCMothers') AND type in ('U'))
  DROP TABLE tmp_ANCMothers
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_Pharmacy') AND type in ('U'))
  DROP TABLE tmp_Pharmacy 
  --IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('mst_patient_decoded') AND type in ('U'))
  --DROP TABLE mst_patient_decoded 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_ARTPatients') AND type in ('U'))
  DROP TABLE tmp_ARTPatients 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_ClinicalEncounters') AND type in ('U'))
  DROP TABLE tmp_ClinicalEncounters 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_FamilyInfo') AND type in ('U'))
  DROP TABLE tmp_FamilyInfo 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_HEI') AND type in ('U'))
  DROP TABLE tmp_HEI 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_LastReportStatus') AND type in ('U'))
  DROP TABLE tmp_LastReportStatus 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_LastStatus') AND type in ('U'))
  DROP TABLE tmp_LastStatus 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_OIs') AND type in ('U'))
  DROP TABLE tmp_OIs 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_Pregnancies') AND type in ('U'))
  DROP TABLE tmp_Pregnancies 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_TBPatients') AND type in ('U'))
  DROP TABLE tmp_TBPatients 
  ---Added by Laureen 
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_HTS_LAB_register') AND type in ('U'))
  DROP TABLE tmp_HTS_LAB_register
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_Referral_Linkage_Register') AND type in ('U'))
  DROP TABLE tmp_Referral_Linkage_Register
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_FamilyTesting_Register') AND type in ('U'))
  DROP TABLE tmp_FamilyTesting_Register
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_PNS_Register') AND type in ('U'))
  DROP TABLE tmp_PNS_Register
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_AnteNatalClinic') AND type in ('U'))
  DROP TABLE tmp_AnteNatalClinic
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_MaternityClinic') AND type in ('U'))
  DROP TABLE tmp_MaternityClinic
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('tmp_PostNatalClinic') AND type in ('U'))
  DROP TABLE tmp_PostNatalClinic
-----------------------------------------------------------------------------------------------------------
  EXEC pr_CreatePatientMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreatePharmacyMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateClinicalEncountersMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateLastStatusMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateARTPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateLabMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreatePregnanciesMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateOIsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateTBPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateHEIMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateANCMothersMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateFamilyInfoMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateIQToolsViews_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreateHTS_Tables_IQTools  @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
  EXEC pr_CreatePMTCT_Tables_IQTools  @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
--  Update aa_Refresh Set Processed = 1,updateDate='2019-01-01' Where RefreshID = @RefreshID
--Fetch Next From @toRefresh Into @RefreshID, @VisitPK, @PatientPK, @VisitType
--Close @toRefresh
--Deallocate @toRefresh
	;with Dups as (select PatientPK, PatientId, row_number() over(Partition by PatientPK order by RegistrationDate) RI from tmp_PatientMaster
	)
	DELETE p
	--SELECT o.ri, *
	FROM dups p
	WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.PatientPK=p.PatientPK GROUP BY PatientPK)

	;with Dups as (select PatientPK, PatientId, row_number() over(Partition by PatientPK order by RegistrationDate) RI from tmp_ARTPatients
	)
	DELETE p
	--SELECT o.ri, *
	FROM dups p
	WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.PatientPK=p.PatientPK GROUP BY PatientPK)
		
	;with Dups as (select ptn_pk, row_number() over(Partition by ptn_pk order by RegistrationDate) RI from mst_patient_decoded
	)
	DELETE p
	--SELECT o.ri, *
	FROM dups p
	WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.ptn_pk=p.ptn_pk GROUP BY ptn_pk)


END

 ELSE
 BEGIN
	  EXEC pr_CreatePatientMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreatePharmacyMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateClinicalEncountersMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateLastStatusMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateARTPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateLabMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreatePregnanciesMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateOIsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateTBPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateHEIMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateANCMothersMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateFamilyInfoMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreateIQToolsViews_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
	  EXEC pr_CreatePMTCT_Tables_IQTools  @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK

	  
		;with Dups as (select PatientPK, PatientId, row_number() over(Partition by PatientPK order by RegistrationDate) RI from tmp_PatientMaster
		)
		DELETE p
		--SELECT o.ri, *
		FROM dups p
		WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.PatientPK=p.PatientPK GROUP BY PatientPK)

		;with Dups as (select PatientPK, PatientId, row_number() over(Partition by PatientPK order by RegistrationDate) RI from tmp_ARTPatients
		)
		DELETE p
		--SELECT o.ri, *
		FROM dups p
		WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.PatientPK=p.PatientPK GROUP BY PatientPK)
		
		;with Dups as (select ptn_pk, row_number() over(Partition by ptn_pk order by RegistrationDate) RI from mst_patient_decoded
		)
		DELETE p
		--SELECT o.ri, *
		FROM dups p
		WHERE RI < (SELECT MAX(RI) FROM dups i WHERE i.ptn_pk=p.ptn_pk GROUP BY ptn_pk)
		
	  EXEC pr_CreateHTS_Tables_IQTools  @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK

 END
  
 END

 end

EXEC pr_CreatePharmacyMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK

exec [pr_RefreshIQTools] 'Jaramogi Oginga Odinga Teaching  Referral Hospital', 'iqcare', '2.0.1'

EXEC pr_CreatePharmacyMaster_IQTools 'Jaramogi Oginga Odinga Teaching  Referral Hospital', 'iqcare', '2.0.1' ,0, 0
EXEC pr_CreateARTPatientsMaster_IQTools 'Jaramogi Oginga Odinga Teaching  Referral Hospital', 'iqcare', '2.0.1' ,0, 0
EXEC pr_CreateHTS_Tables_IQTools 'Jaramogi Oginga Odinga Teaching  Referral Hospital', 'iqcare', '2.0.1' ,0, 0

DECLARE @FacilityName varchar(100)= 'Jaramogi Oginga Odinga Teaching  Referral Hospital'
DECLARE @EMR varchar(10) = 'iqcare'
DECLARE  @EMRVersion varchar(10) = '2.0.1'
DECLARE @VisitPK int = 0 
DECLARE @PatientPK int = 0
-- , @VisitPK int = 0 
EXEC pr_CreatePharmacyMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
EXEC pr_CreateARTPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
 

		select * from tmp_ARTPatients WHERE patientPk = 5064

 /*

 -- Refresh pharmacy data

DECLARE @FacilityName varchar(100)= 'Jaramogi Oginga Odinga Teaching  Referral Hospital'
DECLARE @EMR varchar(10) = 'iqcare'
DECLARE  @EMRVersion varchar(10) = '2.0.1'
DECLARE @VisitPK int = 0 
DECLARE @PatientPK int = 0
-- , @VisitPK int = 0 
EXEC pr_CreatePharmacyMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
EXEC pr_CreateARTPatientsMaster_IQTools @FacilityName, @EMR, @EMRVersion ,@PatientPK, @VisitPK
*/