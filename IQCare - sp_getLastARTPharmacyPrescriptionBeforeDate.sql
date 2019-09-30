IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('sp_getLastARTPharmacyPrescriptionBeforeDate') AND type= 'P')
	DROP PROCEDURE sp_getLastARTPharmacyPrescriptionBeforeDate
GO

/****** Object:  StoredProcedure [dbo].[sp_getLastARTPharmacyPrescriptionBeforeDate]    Script Date: 10/30/2018 6:05:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kenneth O. Ochieng
-- Create date: 30th October 2018
-- Description:	Get Patient's last ART Prescription Before Given Date
-- =============================================================
CREATE PROCEDURE [dbo].sp_getLastARTPharmacyPrescriptionBeforeDate
	-- Add the parameters for the stored procedure here
	@PatientId int = null,
	@VisitDate Date = null

AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
Set Nocount On;

	begin
		SELECT   top 1     o.DispensedByDate, a.Drug_Pk, 0 AS batchId, a.FrequencyID, b.Abbreviation AS abbr, b.DrugName, '' AS batchName, a.SingleDose AS dose, d.Name AS freq, a.Duration, a.OrderedQuantity, 
								 a.DispensedQuantity, a.Prophylaxis
		FROM            dtl_PatientPharmacyOrder AS a INNER JOIN
								 Mst_Drug AS b ON a.Drug_Pk = b.Drug_pk INNER JOIN
								 ord_PatientPharmacyOrder AS o ON a.ptn_pharmacy_pk = o.ptn_pharmacy_pk LEFT OUTER JOIN
								 mst_Frequency AS d ON a.FrequencyID = d.ID
		WHERE        (b.Abbreviation IS NOT NULL) AND o.PatientId = @PatientId AND o.DispensedByDate < @VisitDate ORDER BY o.DispensedByDate DESC
	end
	
End
