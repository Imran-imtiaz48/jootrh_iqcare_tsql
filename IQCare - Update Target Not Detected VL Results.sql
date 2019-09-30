UPDATE dtl_LabOrderTestResult SET ResultText = 'Target Not Detected', ResultValue = 0 
WHERE HasResult = 1 AND ResultValue IS NULL AND ParameterId IN (3,107) AND Undetectable = 0
