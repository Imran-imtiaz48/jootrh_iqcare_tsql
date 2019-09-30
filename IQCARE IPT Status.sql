DECLARE @fromDate AS DATE = '2009-01-01';
DECLARE @toDate AS DATE = '2018-01-01';

SELECT a.PatientPK,
      a.VisitDate,
      a.IPTStartdate,
      b.IPTOutcome,
      b.IPTOutcomeDate,
      CASE
        WHEN DateAdd(mm, 6, a.IPTStartdate) > @todate AND
        b.IPTOutcome IS NULL THEN 'Currently On IPT'
        WHEN b.IPTOutcome LIKE '%Completed%' AND DateDiff(mm, a.IPTStartdate,
        b.IPTOutcomeDate) >= 6 THEN 'Completed IPT' ELSE b.IPTOutcome
      END IPTStatus
    FROM (SELECT *
      FROM (SELECT a.ptn_pk PatientPK,
          CAST(d.VisitDate AS date) VisitDate,
          CAST(w.IptStartDate AS date) IPTStartdate,
          Dense_Rank() OVER (PARTITION BY a.ptn_pk ORDER BY w.IptStartDate DESC)
          Rank
        FROM dbo.Patient a
          INNER JOIN dbo.PatientIptWorkup w ON a.Id = w.PatientId
          LEFT JOIN dbo.PatientIptOutcome b ON a.Id = b.PatientId
          LEFT JOIN dbo.PatientMasterVisit c ON (b.PatientMasterVisitId = c.Id OR b.visitDate = c.VisitDate) TODO:TODO
          LEFT JOIN dbo.PatientMasterVisit d ON (w.PatientMasterVisitId = d.Id OR w.VisitDate = d.Visitdate) TODO:TODO
        WHERE d.VisitDate IS NOT NULL AND d.VisitDate <= CAST(@todate AS
          datetime) AND w.IptStartDate <= CAST(@todate AS datetime)) a
      WHERE a.Rank = 1) a
      LEFT JOIN (SELECT *
      FROM (SELECT a.ptn_pk PatientPK,
          b.ReasonForDiscontinuation IPTOutcome,
          c.VisitDate IPTOutcomeDate,
          Dense_Rank() OVER (PARTITION BY a.ptn_pk ORDER BY c.VisitDate DESC)
          Rank
        FROM dbo.Patient a
          INNER JOIN dbo.PatientIptOutcome b ON a.Id = b.PatientId
          LEFT JOIN dbo.PatientMasterVisit c ON b.PatientMasterVisitId = c.Id
        WHERE c.VisitDate <= CAST(@todate AS datetime)) b
      WHERE b.Rank = 1) b ON a.PatientPK = b.PatientPK

