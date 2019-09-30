IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_getEncounter') and type = 'P')
	DROP  PROCEDURE sp_getEncounter
GO
-- Get Encounter. If not existing, create a new one
CREATE PROCEDURE sp_getEncounter
(
	@PatientMasterVisitId AS INT,
	@EncounterTypeId AS INT,
	@PatientId AS INT,
	@UserId AS INT,
	@EncounterId AS INT out
)
AS
BEGIN
	DECLARE @createDate as DATE = getdate()
	DECLARE @serviceAreaId as int = 205 -- Greencard
	DECLARE @visitDate as DATE

	SELECT @visitDate = VisitDate FROM PatientMasterVisit WHERE Id = @PatientMasterVisitId

	SELECT @EncounterId = Id FROM PatientEncounter WHERE PatientMasterVisitId = @PatientMasterVisitId AND EncounterTypeId = @EncounterTypeId
	IF @@ROWCOUNT = 0
	BEGIN
		exec sp_executesql N'INSERT [dbo].[PatientEncounter]([PatientId], [EncounterTypeId], [Status], [PatientMasterVisitId], [EncounterStartTime], [EncounterEndTime], [ServiceAreaId], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
		VALUES (@0, @1, @2, @3, @4, @5, @6, NULL, @7, @8, @9)
		',N'@0 int,@1 int,@2 int,@3 int,@4 datetime2(7),@5 datetime2(7),@6 int,@7 datetime2(7),@8 int,@9 bit',
		@0=@patientId,@1=@encounterTypeId,@2=0,@3=@patientMasterVisitId,@4=@visitDate,@5=@visitDate,@6=@serviceAreaId,@7=@createDate,@8=@userId,@9=0

		SET @EncounterId = IDENT_CURRENT('PatientEncounter')
	END		
END
