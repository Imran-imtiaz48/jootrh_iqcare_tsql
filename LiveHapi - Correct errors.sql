SELECT        TOP (200) cs.Id, cs.FirstName, cs.LastName, cs.MiddleName, cs.Serial, cs.SyncStatusInfo, Users.UserName, Users.SourceRef, Users.Id AS Expr1
FROM            ClientStages AS cs INNER JOIN
                         Clients AS c ON cs.ClientId = c.Id INNER JOIN
                         Users ON c.UserId = Users.Id INNER JOIN
                         Encounters AS e ON cs.Id = e.ClientId
WHERE        (cs.SyncStatusInfo LIKE '%already exists%') AND (Users.SourceRef = '155')


UPDATE ClientStages SET Serial = CONCAT('OPD ',Serial) WHERE Id IN (
	SELECT        cs.id
	FROM            ClientStages AS cs INNER JOIN
							 Clients AS c ON cs.ClientId = c.Id INNER JOIN
							 Users ON c.UserId = Users.Id
	WHERE        (cs.SyncStatusInfo LIKE '%already exists%')
	AND SourceRef = '155'
)

select * from ClientStages WHERE ClientId = '5dc07686-febf-45ac-b650-aa6400c1f5bd'

select * from Encounters WHERE clientId =  '5dc07686-febf-45ac-b650-aa6400c1f5bd'