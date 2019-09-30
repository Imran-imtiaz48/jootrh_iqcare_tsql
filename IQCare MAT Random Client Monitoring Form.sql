/* RANDOM CLIENT MONITORING FORM */ 
OPEN symmetric KEY key_ctc decryption BY password='ttwbvXWpqb5WOLfLrBgisw=='; 

SELECT P.matid, 
       Cast(Decryptbykey(P.firstname) AS VARCHAR(50)) AS FirstName, 
       Cast(Decryptbykey(P.lastname) AS VARCHAR(50))  AS LastName, 
       Cast(P.dob AS DATE)                            AS DOB, 
       P.sex, 
       Cast(P.registrationdate AS DATE)               AS RegistrationDate, 
       Cast(V.visitdate AS DATE)                      AS VisitDate, 
       CMF.pulse, 
       CMF.oxygensaturation, 
       CMF.diastolicbp, 
       CMF.systolicbp, 
       CMF.temperature, 
       CMF.respiratoryrate, 
       CMF.bmi, 
       CMF.matdurationdate                            AS DuratinSinceMatInit, 
       CMF.mattime                                    AS TimeOfDay, 
       Cast(CMF.matimedate AS DATE)                   AS DateLastOpiodUse, 
       mst_YesNo_2.NAME                               AS 
       UsesOtherPsychoactiveSub, 
       CMF.matmethtime                                AS TimeMethDosing, 
       CMF.matmethadonedose                           AS MethDose, 
       CMF.maturinescreen                             AS UrineDrugScreenRes, 
       CMF.matalcoblow                                AS AlcoblowResult, 
       CMF.matwithdrawal                              AS WithdrawalSymp, 
       CMF.matoxicity                                 AS Toxixity, 
       mst_YesNo_1.NAME                               AS OnART, 
       CMF.othervmmcprescomplaints                    AS OnOtherMeds, 
       mst_yesno.NAME                                 AS NeedMethDoseAdj, 
       mst_decode.NAME                                AS ReasonForDoseAjust, 
       CMF.matcurrentmethadonedose                    AS RecommendedDose 
FROM   dtl_fbcustomfield_mat_random_client_monitoring_form AS CMF 
       INNER JOIN mst_patient AS P 
               ON CMF.ptn_pk = P.ptn_pk 
       INNER JOIN ord_visit AS V 
               ON CMF.visit_pk = V.visit_id 
       INNER JOIN mst_yesno 
               ON CMF.matneedadjust = mst_yesno.id 
       LEFT OUTER JOIN mst_yesno AS mst_YesNo_2 
                    ON CMF.matpsdate = mst_YesNo_2.id 
       LEFT OUTER JOIN mst_yesno AS mst_YesNo_1 
                    ON CMF.art = mst_YesNo_1.id 
       LEFT OUTER JOIN mst_decode 
                    ON CMF.matdoseadjust = mst_decode.id 

CLOSE symmetric KEY key_ctc 