
Select a.ptn_pk, a.visit_pk, 
Case WHEN b.Name = 'Other (specify)' THEN a.PwPOther ELSE b.Name END AS PwP  
From dtl_PatientPreventionwithpositives a 
Inner Join mst_BlueDecode b on a.ID = b.ID
INNER JOIN dbo.ord_Visit c ON a.Visit_Pk = c.Visit_Id AND a.Ptn_Pk = c.Ptn_Pk
Where  (c.DeleteFlag IS NULL OR c.DeleteFlag = 0)
order by visit_pk desc
union 
Select p.ptn_pk, p.Visit_pk, p.Pwp
From IQC_PWP p 
--order by p.Ptn_pk desc