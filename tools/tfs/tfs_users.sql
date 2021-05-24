USE [Tfs_YourTeamProjectCollectionNameHere]  -- Optional if you already have Query connected to your TPC.
SELECT IdentityName AS [User], Max(StartTime) AS [LastConnect] 
FROM tbl_Command with (nolock) 
GROUP BY IdentityName 
ORDER BY [LastConnect] DESC
