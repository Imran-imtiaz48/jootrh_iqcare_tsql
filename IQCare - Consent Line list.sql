;WITH ct_cte AS (
	SELECT pt.Id AS PatientID,
	  pt.ptn_pk,
      pt.PersonId,
      tp.PatientName,
      tp.PhoneNumber,
      g.PatientEnrollmentID AS EnrollmentNumber,
      CASE WHEN g.Sex = 52 THEN 'F' ELSE 'M' END AS Sex,
      CAST(CASE WHEN TI.TransferInDate IS NOT NULL THEN TI.TransferInDate
        ELSE g.RegistrationDate END AS Date) AS EnrollmentDate,
      P.NextAppointmentDate,
      CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason
      END PatientStatus
    FROM mst_Patient g
	INNER JOIN Patient pt ON pt.ptn_pk = g.Ptn_Pk
      LEFT JOIN (SELECT ce.PatientId,
        ce.ExitReason,
        ce.ExitDate,
        ce.TransferOutfacility,
        ce.CreatedBy
      FROM (SELECT ce.PatientId,
          l.Name AS ExitReason,
          ce.ExitDate,
          ce.TransferOutfacility,
          ce.CreatedBy,
          Row_Number() OVER (PARTITION BY ce.PatientId ORDER BY ce.CreateDate
          DESC) AS RowNum
        FROM patientcareending ce
          INNER JOIN LookupItem l ON l.Id = ce.ExitReason
        WHERE ce.DeleteFlag = 0) ce
      WHERE ce.RowNum = 1) ce ON pt.Id = ce.PatientId
      LEFT JOIN (SELECT DISTINCT p.PatientPK,
        UPPER(p.PatientName) AS PatientName,
        p.ContactPhoneNumber,
        p.PhoneNumber,
        p.ContactName,
        p.MaritalStatus,
        p.EducationLevel,
        CONCAT(p.Landmark, '-', p.NearestHealthCentre) AS Address
      FROM IQTools_KeHMIS.dbo.tmp_PatientMaster p) tp ON tp.PatientPK = g.ptn_pk
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = pt.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X 
      WHERE X.CreatedBy <> 114
      GROUP BY X.PatientId) P ON pt.Id = P.PatientId
),
consent_cte AS (
		SELECT distinct patientid, CAST(c.ConsentDate AS DATE) AS ConsentDate FROM PatientConsent c
		WHERE ConsentType = 265
		AND CreatedBy = 0
	)

SELECT 
	a.PatientId,
	a.EnrollmentNumber AS PatientId, 
	a.PatientName, 
	c.ConsentDate,
	a.NextAppointmentDate, 
	CASE WHEN (PhoneNumber LIKE '07[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' OR PhoneNumber LIKE '2547[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' OR PhoneNumber LIKE '+2547[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') THEN 'Y' ELSE 'N' END
	  AS ValidPhoneNumber,
	a.PhoneNumber 
FROM consent_cte c INNER JOIN ct_cte a ON c.PatientId = a.PatientID
ORDER BY ConsentDate DESC, NextAppointmentDate DESC

return
SELECT * FROM Patient WHERE id = 4602 -- 4603 -- 7706


SELECT PhoneNumber FROM IQTools_KeHMIS.dbo.tmp_PatientMaster a WHERE a.PatientPK = 3498


exec pr_OpenDecryptedSession
SELECT convert(varchar(100),pv.Phone) dPhone FROM PatientView pv WHERE Ptn_Pk = 4603 

SELECT convert(varchar(100),DECRYPTBYKEY(pv.Phone)) dPhone FROM mst_Patient pv WHERE Ptn_Pk = 3498 


SELECT convert(varchar(100),DECRYPTBYKEY(pv.MobileNUmber)) FROM PersonContact pv WHERE personId = 5689

return


-- UPDATE mst_patient WITH valid phone numbers
UPDATE mp
SET mp.Phone = c.MobileNumber
--SELECT  convert(varchar(100),DECRYPTBYKEY(c.MobileNUmber)) MObile, convert(varchar(100),DECRYPTBYKEY(mp.Phone)) Phone 
FROM 
PersonContact c 
INNER JOIN patient p ON c.PersonId = p.PersonId
INNER JOIN mst_Patient mp ON mp.Ptn_Pk =p.ptn_pk
WHERE
--AND p.PersonId = 5689
mp.Phone <> c.MobileNumber

select * from IQTools_KeHMIS.dbo.mst_patient_decoded WHERE Ptn_Pk = 3498

--25644

Select convert(varchar(100),pv.MiddleName) dMiddleName, convert(varchar(100),pv.firstname) dFirstName, 
convert(varchar(100),pv.LastName)dLastName, convert(varchar(100),pv.Address)dAddress, convert(varchar(100),pv.Phone) dPhone
--INTO IQCare_CPAD.dbo.mst_patient_decoded 
From IQCare_CPAD.dbo.mst_patient a left outer join IQCare_CPAD.dbo.patient b on a.ptn_pk=b.ptn_pk inner join IQCare_CPAD.dbo.PatientView pv 
on pv.Ptn_Pk=a.Ptn_Pk   
Where (a.deleteflag is null or a.deleteflag=0 ) AND pv.Ptn_Pk = 3498


SELECT CONVERT(varchar(100), Decryptbykey(Phone)) Phone FROM mst_Patient WHERE Ptn_Pk = 3498


SELECT * FROM gcPatientView WHERE EnrollmentNumber = '13939-25644'


SELECT * FROM PatientLabTracker WHERE patientId =  9754


