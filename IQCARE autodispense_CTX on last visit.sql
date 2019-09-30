/*
	This script will auto-prescribe a CTX drug (Sulfa/TMX-Cotrimoxazole 960mg 800mg/160mg ) to
	each and every patient for whom the last visit contains no CTX presciption
	The same drug will be dispensed for both adults and paeds
	The amount of drugs prescribed will be in multiples of 28 and this will be determined by the number of
	days between the last visit date and the next appointment date

	@author:		Kenneth Omondi Ochieng
	@organization:	CIP-KENYA
	@date:			7th Feb 2018
	With guidance from Stephen Osewe
	Palladim Group - Kenya
*/


BEGIN TRY 
	DROP table #tmpMissingCTX
END TRY
BEGIN CATCH
END CATCH

set rowcount 0

/*
Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw=='
GO
*/

exec pr_OpenDecryptedSession
go

WITH last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v
	WHERE v.CreatedBy > 1
	) lastVisit WHERE rowNum = 1
),

ctx_cte AS (
	SELECT        ord.PatientMasterVisitId, ord.PatientId, dis.Drug_Pk, dis.Prophylaxis, ord.orderstatus, dr.DrugName, ord.Ptn_pk, dis.OrderedQuantity, dis.DispensedQuantity, dis.Duration, dis.FrequencyID, dis.StrengthID
	FROM            ord_PatientPharmacyOrder AS ord INNER JOIN
							 dtl_PatientPharmacyOrder AS dis ON ord.ptn_pharmacy_pk = dis.ptn_pharmacy_pk INNER JOIN
							 Mst_Drug_Bill AS dr ON dis.Drug_Pk = dr.Drug_pk
	WHERE        (dr.DrugName LIKE '%cotrimoxazole%' OR
							 dr.DrugName LIKE '%DAPSONE%') AND (dr.DeleteFlag = 0) AND (ord.DeleteFlag = 0) AND (NOT (ord.PatientMasterVisitId IS NULL))
),

last_visit_n_ctx AS (
	SELECT v.PatientId,v.PatientMasterVisitId,v.lastVisitDate,v.lastProvider,c.DrugName, c.OrderedQuantity, c.DispensedQuantity, c.Duration, c.FrequencyID, c.StrengthID 
	FROM 
		last_visit_cte v 
	LEFT OUTER JOIN ctx_cte c ON c.PatientMasterVisitId = v.PatientMasterVisitId 
),

next_appointment_cte AS (
	SELECT AppointmentDate as nextAppointmentDate, PatientId FROM (
	SELECT ROW_NUMBER() OVER (Partition by a.PatientId Order By appointmentDate Desc) as rowNum,a.PatientId,a.AppointmentDate FROM PatientAppointment a WHERE a.ReasonId = 232 --Follow Up
	) nextAppointment WHERE rowNum = 1
)

SELECT 
	pv.ptn_pk, pv.EnrollmentNumber, pv.FirstName, pv.MiddleName, pv.LastName, pv.DateOfBirth, pv.Sex, pv.Id as PatientId,
	lvc.lastVisitDate, lvc.DrugName, lvc.PatientMasterVisitId, lvc.lastProvider, lvc.OrderedQuantity, lvc.DispensedQuantity, lvc.Duration, lvc.FrequencyID, lvc.StrengthID,
	DATEDIFF(YY,pv.DateOfBirth,lvc.lastVisitDate) as ageAtLastVisit,
	na.nextAppointmentDate, ISNULL(DATEDIFF(D, lvc.lastVisitDate, na.nextAppointmentDate), 0) as daysToTCADate
INTO #tmpMissingCTX
FROM gcPatientView pv 
	LEFT OUTER JOIN last_visit_n_ctx lvc ON lvc.PatientId = pv.Id 
	LEFT OUTER JOIN next_appointment_cte na ON na.PatientId = pv.Id
WHERE pv.PatientStatus = 'ACTIVE' 

SELECT * FROM #tmpMissingCTX WHERE DrugName IS NULL AND lastVisitDate IS NOT NULL
set rowcount 0

/*
	Auto prescribe and dispense CTX to patients who's last visits don't have a CTX prescription
*/

declare @ptn_pk AS int
declare @PatientMasterVisitID int = 0
declare @PatientId int = null
declare @LocationID int = null 
declare @OrderedBy int = null
declare @UserID int = null 
declare @RegimenType varchar(50) = null
declare @DispensedBy int=null 
declare @RegimenLine int = null
declare @PharmacyNotes varchar(200) = null
declare @ModuleID int = ''
declare @lastProvider int = null

declare @TreatmentProgram int = null
declare @PeriodTaken int = null

declare @TreatmentPlan int = null 
declare @TreatmentPlanReason int = null
declare @Regimen int = 0
declare @PrescribedDate varchar(50) = null
declare @DispensedDate varchar(50) = null 

declare @ptn_pharmacy_pk AS float
declare @drugId AS float
declare @ageAtLastVisit AS int
declare @daysToTCADate AS int
declare @qty AS int 

SELECT @ptn_pk = min(ptn_pk) FROM #tmpMissingCTX WHERE DrugName IS NULL AND lastVisitDate IS NOT NULL

WHILE @ptn_pk IS NOT NULL
BEGIN
	SELECT 
		@PatientMasterVisitID = PatientMasterVisitId,
		@PatientId = PatientId,
		@LocationID=N'754', --jootrh
		@OrderedBy = lastProvider,
		@UserID= lastProvider,
		@DispensedBy = lastProvider,
		@TreatmentProgram = N'225', --non-art
		@PrescribedDate = lastVisitdate,
		@DispensedDate = lastVisitDate,
		@ageAtLastVisit = ageAtLastVisit,
		@daysToTCADate = daysToTCADate
	FROM #tmpMissingCTX WHERE ptn_pk = @ptn_pk

	exec sp_SaveUpdatePharmacy_GreenCard 
		@PatientMasterVisitID=@PatientMasterVisitID,
		@PatientId=@PatientId,
		@LocationID=@LocationID,
		@OrderedBy=@OrderedBy,
		@UserID=@UserID,
		@RegimenType=N'',
		@DispensedBy=@DispensedBy,
		@RegimenLine=N'0',
		@ModuleID=N'',
		@TreatmentProgram=@TreatmentProgram,
		@PeriodTaken=N'0',
		@TreatmentPlan=N'0',
		@TreatmentPlanReason=N'0',
		@Regimen=N'0',
		@PrescribedDate=@PrescribedDate,
		@DispensedDate=@DispensedDate

	SET @ptn_pharmacy_pk = IDENT_CURRENT('ord_PatientPharmacyOrder')  

	exec sp_DeletePharmacyPrescription_GreenCard 
		@ptn_pharmacy_pk=@ptn_pharmacy_pk

	/*
	IF @ageAtLastVisit >= 18
		SET @drugId = 1022 -- Sulfa/TMX-Cotrimoxazole 960mg 800mg/160mg for Adults 
	ELSE
		SET @drugId = 1015 -- Sulfa/TMX-Cotrimoxazole 480mg 80mg for Paeds
	END
	*/

	SET @drugId = 1022 -- Sulfa/TMX-Cotrimoxazole 960mg 800mg/160mg 
	
	IF @daysToTCADate < 28
		SET @qty = 84
	ELSE
		SET @qty = ROUND(@daysToTCADate/28,0)*28 --Round off the qty o the nearest 28 days(prescription period)
	
	exec sp_SaveUpdatePharmacyPrescription_GreenCard 
		@ptn_pharmacy_pk=@ptn_pharmacy_pk,
		@DrugId=@drugId,
		@BatchId=N'0',
		@FreqId=N'1',
		@Dose=N'1',
		@Duration=@qty,
		@qtyPres=@qty,
		@qtyDisp=@qty,
		@prophylaxis=N'1',
		@pmscm=N'0',
		@UserID=@lastProvider

	DELETE FROM #tmpMissingCTX WHERE ptn_pk = @ptn_pk 
	SELECT @ptn_pk = min(ptn_pk) FROM #tmpMissingCTX

END

SELECT * FROM #tmpMissingCTX 
-- WHERE 
-- lastVisitDate IS NULL
-- ageAtLastVisit > 17
-- DrugName != 'Sulfa/TMX-Cotrimoxazole 960mg 800mg/160mg'
-- DrugName  IS NULL


/*
	SQLCMD Execution
	================
	sqlcmd -S .\sqlexpress -Usa -Pmaun2806 -d IQCARE_CPAD -i "IQCare get_active_patients_not_on_CTX.sql"
*/