Declare @InstanceName varchar(max)
Declare @Tsql varchar(max);

SET @InstanceName = 'IQCare_CPAD_MASHUPMAR2017'; 

		Set @Tsql = ('exec( '' Update ' + @InstanceName + '.dbo.mst_patient Set
						FirstName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	MiddleName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	LastName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	Address = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	Phone = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))  ; 
				 Update ' + @InstanceName + '.dbo.dtl_patientcontacts Set
						GuardianName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	GuardianInformation = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	EmergContactName = (select Random_String from vw_GenNewId)
					,	EmergContactPhone = (select Random_String from vw_GenNewId)
					,	EmergContactAddress = (select Random_String from vw_GenNewId)
					,	TenCellLeader = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	TenCellLeaderAddress = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	TreatmentSupportName = (select Random_String from vw_GenNewId)
					,	CommunitySupportGroup = (select Random_String from vw_GenNewId)
					,	TreatmentSupportAddress = (select Random_String from vw_GenNewId)       
  
				Update ' + @InstanceName + '.dbo.dtl_FamilyInfo Set
						RFirstName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId))
					,	RLastName = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId)) ;       
				Update ' + @InstanceName + '.dbo. mst_Employee Set
					LastName = (select Random_String from vw_GenNewId)
				,	FirstName = (select Random_String from vw_GenNewId);
			Update ' + @InstanceName + '.dbo.mst_User Set
					UserLastName = (select Random_String from vw_GenNewId)
				,	UserFirstName = (select Random_String from vw_GenNewId);
			Update ' + @InstanceName + '.dbo.Person Set
				FirstName =encryptbykey(key_guid(''''Key_CTC''''),(select Random_String from vw_GenNewId)),
				MidName = encryptbykey(key_guid(''''Key_CTC''''),(select Random_String from vw_GenNewId)),
				LastName= encryptbykey(key_guid(''''Key_CTC''''),(select Random_String from vw_GenNewId));
			Update ' + @InstanceName + '.dbo. PersonContact Set
				PhysicalAddress = encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId)),
				MobileNumber= encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId)),
				AlternativeNumber =encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId)),
				EmailAddress=encryptbykey(key_guid(''''Key_CTC''''), (select Random_String from vw_GenNewId));
			Update ' + @InstanceName + '.dbo.PersonLocation Set
				Location= (select Random_String from vw_GenNewId),
				Village= (select Random_String from vw_GenNewId),
				SubCounty= (select Random_String from vw_GenNewId),
				LandMark= (select Random_String from vw_GenNewId),
				NearestHealthCentre=(select Random_String from vw_GenNewId)'')');
Print @Tsql

exec pr_OpenDecryptedSession
go

exec( ' Update IQCare_CPAD_MASHUPMAR2017.dbo.mst_patient Set
						FirstName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	MiddleName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	LastName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	Address = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	Phone = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))  ; 
				 Update IQCare_CPAD_MASHUPMAR2017.dbo.dtl_patientcontacts Set
						GuardianName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	GuardianInformation = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	EmergContactName = (select Random_String from vw_GenNewId)
					,	EmergContactPhone = (select Random_String from vw_GenNewId)
					,	EmergContactAddress = (select Random_String from vw_GenNewId)
					,	TenCellLeader = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	TenCellLeaderAddress = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	TreatmentSupportName = (select Random_String from vw_GenNewId)
					,	CommunitySupportGroup = (select Random_String from vw_GenNewId)
					,	TreatmentSupportAddress = (select Random_String from vw_GenNewId)       
  
				Update IQCare_CPAD_MASHUPMAR2017.dbo.dtl_FamilyInfo Set
						RFirstName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId))
					,	RLastName = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId)) ;       
				Update IQCare_CPAD_MASHUPMAR2017.dbo. mst_Employee Set
					LastName = (select Random_String from vw_GenNewId)
				,	FirstName = (select Random_String from vw_GenNewId);
			Update IQCare_CPAD_MASHUPMAR2017.dbo.mst_User Set
					UserLastName = (select Random_String from vw_GenNewId)
				,	UserFirstName = (select Random_String from vw_GenNewId);
			Update IQCare_CPAD_MASHUPMAR2017.dbo.Person Set
				FirstName =encryptbykey(key_guid(''Key_CTC''),(select Random_String from vw_GenNewId)),
				MidName = encryptbykey(key_guid(''Key_CTC''),(select Random_String from vw_GenNewId)),
				LastName= encryptbykey(key_guid(''Key_CTC''),(select Random_String from vw_GenNewId));
			Update IQCare_CPAD_MASHUPMAR2017.dbo. PersonContact Set
				PhysicalAddress = encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId)),
				MobileNumber= encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId)),
				AlternativeNumber =encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId)),
				EmailAddress=encryptbykey(key_guid(''Key_CTC''), (select Random_String from vw_GenNewId));
			Update IQCare_CPAD_MASHUPMAR2017.dbo.PersonLocation Set
				Location= (select Random_String from vw_GenNewId),
				Village= (select Random_String from vw_GenNewId),
				--SubCounty= (select Random_String from vw_GenNewId),
				LandMark= (select Random_String from vw_GenNewId),
				NearestHealthCentre=(select Random_String from vw_GenNewId)')
