IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_saveFpMethod') AND type= 'P')
	DROP PROCEDURE sp_saveFpMethod
GO

CREATE PROCEDURE sp_saveFpMethod 
@PatientId AS INT,
@PatientFpId AS INT,
@FpMethodId AS INT
AS
		DECLARE @CreateDate AS DATETIME
		SET @CreateDate = GETDATE()
		IF NOT EXISTS (SELECT * FROM PatientFamilyPlanningMethod WHERE PatientID = @PatientId AND PatientFPId = @PatientFpId AND FPMethodId = @FpMethodId)
			exec sp_executesql N'INSERT [dbo].[PatientFamilyPlanningMethod]
			([PatientId], [PatientFPId], [FPMethodId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
			VALUES (@0, @1, @2, NULL, @3, @4, @5)',N'@0 int,@1 int,@2 int,@3 datetime2(7),@4 int,@5 bit',
			@0=@PatientId,@1=@PatientFpId,@2=@FpMethodId,@3=@CreateDate,@4=1,@5=0
