USE [IQCare_CPAD]
GO

/****** Object:  View [dbo].[BlueCardAppointmentView]    Script Date: 8/30/2018 3:00:37 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[BlueCardAppointmentView]
AS
SELECT        TOP (1) NULL AS PatientId, NULL AS AppointmentId, NULL AS FacilityName, NULL AS VisitId, NULL AS Appointmentdate, NULL AS Reason, NULL AS AppointmentStatus, NULL AS Provider, NULL 
                         AS Description, NULL AS ServiceArea, NULL AS StatusDate, NULL AS RowId

GO


USE [IQCare_CPAD]
GO

/****** Object:  View [dbo].[facilityStatisticsView]    Script Date: 8/30/2018 3:01:02 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[facilityStatisticsView]
AS
SELECT        0 AS Id, 0 AS TotalCumulativePatients, 0 AS TotalActiveOnArt, 0 AS TotalTransferIn, 0 AS TotalPatientsTransferedOut, 0 AS TotalOnCtxDapson, 0 AS TotalPatientsDead, 0 AS TotalTransit, 0 AS LostToFollowUp, 
                         0 AS TotalUndocumentedLTFU

GO



