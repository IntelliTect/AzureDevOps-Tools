# Move all Contributors to Readers
#
# Members of groups such as Project Administrator or Build Administrator groups are not affected

$groups = Get-ADOGroups `
	-OrgName $SourceOrgName `
	-ProjectName $SourceProjectName `
	-PersonalAccessToken $SourcePAT
$contributors = $groups | Where-Object { $_.Name -eq "Contributors" }
$readers = $groups | Where-Object { $_.Name -eq "Readers" } 

write-host "Adding all Contributor group user members to Readers ..."
foreach ($u in $contributors.UserMembers) { 
	az devops security group membership add --group-id $readers.Descriptor --member-id $u.PrincipalName --detect $false 
}
foreach ($g in $contributors.GroupMembers) { 
	az devops security group membership add --group-id $readers.Descriptor --member-id $g.PrincipalName --detect $false 
}
foreach ($g in $contributors.GroupMembers) { 
	az devops security group membership remove --group-id $contributors.Descriptor --member-id $g.PrincipalName --detect $false 
}   
foreach ($u in $contributors.UserMembers) { 
	az devops security group membership remove --group-id $contributors.Descriptor --member-id $u.PrincipalName --detect $false --yes 
}

