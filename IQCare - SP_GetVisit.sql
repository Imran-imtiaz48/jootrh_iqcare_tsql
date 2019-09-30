IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_getVisit') and type = 'P')
	DROP  PROCEDURE sp_getVisit
GO
-- Get Visit. If not existing, create a new one
CREATE PROCEDURE sp_getVisit
(@VisitDate AS DATE,
@PatientId AS INT,
@PatientMasterVisitId AS INT out,
@VisitId AS INT out, 
@UserId AS INT out)
AS
BEGIN
	DECLARE @PtnPk AS INT
	DECLARE @locationId as INT = 754
	DECLARE @visitType as INT = 6
	DECLARE @typeOfVisit as INT = 70
	DECLARE @moduleId as INT = 203
	DECLARE @createDate as DATE = getdate()

	SET @PtnPk = (SELECT p.ptn_pk FROM patient p WHERE id = @PatientId) 
	SELECT 
			@PatientMasterVisitID = Id, @UserID = CreatedBy
	FROM PatientMasterVisit 
	WHERE 
		PatientId = @PatientId AND (ABS((DATEDIFF (hour, ISNULL([Start],VisitDate), @visitDate))) <= 24)

	if	@@ROWCOUNT = 0 
	BEGIN
		INSERT [dbo].[PatientMasterVisit]([PatientId], [ServiceId], [Start], [End], [VisitScheduled], [VisitBy], [VisitType], [VisitDate], [Active], [Status], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
		VALUES (@PatientId, 1, @visitDate, @visitDate, NULL, NULL, NULL, @visitDate, 0, 1, NULL, GETDATE(), 1, 0)
			
		SET @PatientMasterVisitID = IDENT_CURRENT('PatientMasterVisit')
		SET @UserID = 1

	END

	--xxxxxxxxxxxxxxxxxx -- Begin, Repeat above for ord_visit table
	SELECT 
			@visitId = Visit_Id, @UserID = CreatedBy
	FROM ord_Visit 
	WHERE 
		Ptn_Pk = @PtnPk AND ((DATEDIFF (hour, ISNULL(VisitDate,CreateDate), @visitDate)) <= 24)

	if	@@ROWCOUNT = 0 
	BEGIN
		exec sp_executesql N'INSERT [dbo].[ord_Visit]
			([Ptn_Pk], [LocationID], [VisitDate], [VisitType], [DataQuality], [UserID], [TypeofVisit], [OrderedBy], [ReportedBy], [Signature], [ModuleId], [old_signature_employee_id], [AuditData], [CreateDate], [CreatedBy], [DeleteFlag])
		VALUES (@0, @1, @2, @3, 1, @4, @5, @6, @7, @8, @9, @10, NULL, @11, @12, @13)
		',N'@0 int,@1 int,@2 datetime2(7),@3 int,@4 int,@5 int,@6 int,@7 int,@8 int,@9 int,@10 int,@11 datetime2(7),@12 int,@13 bit',
		@0=@PtnPk,@1=@locationId,@2=@visitDate,@3=@visitType,@4=@userId,@5=@typeOfVisit,@6=0,@7=0,@8=0,@9=@moduleId,@10=0,@11=@createDate,@12=@userId,@13=0
			
		SET @visitId = IDENT_CURRENT('ord_Visit')
		SET @UserID = 1
	END
	--xxxxxxxxxxxxxxxxxxxxx -- End, Repeat above for ord_visit table
END


