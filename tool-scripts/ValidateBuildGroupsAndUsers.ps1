
param (
    [Parameter (Mandatory = $TRUE)]
    [String]$SourceOrgName, 

    [Parameter (Mandatory = $TRUE)]
    [String]$SourceProjectName, 
    
    [Parameter (Mandatory = $TRUE)]
    [String]$SourcePAT,

    [Parameter (Mandatory = $TRUE)]
    [String]$TargetOrgName, 

    [Parameter (Mandatory = $TRUE)]
    [String]$TargetProjectName, 
    
    [Parameter (Mandatory = $TRUE)]
    [String]$TargetPAT,

    [Parameter (Mandatory = $TRUE)]
    [String]$OutputFile
    
)

    Write-Host " "
    Write-Host '----------------------------------------'
    Write-Host '-- Validate Migrated Groups and Users --'
    Write-Host '----------------------------------------'
    Write-Host " "
 
    # # Create Headers
    # $SourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
    # $Targetheaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

    Write-Log -Message 'Get Source Group'
    $sourceGroups = Get-ADOGroups -OrgName $SourceOrgName  -ProjectName $SourceProjectName -PersonalAccessToken $SourcePAT
    Write-Log -Message 'Get Target Group'
    $targetGroups = Get-ADOGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName  -PersonalAccessToken $TargetPAT

    Start-Transcript -Path $OutputFile -Append

    Write-Host " "
    Write-Host " "
    Write-Host "Source Group Count: $($sourceGroups.Count)"
    Write-Host "Target Group Count: $($targetGroups.Count)"
    Write-Host " "

    $groupsInSourceNotInTarget = $sourceGroups | Where-Object { $_.name -notin $targetGroups.name }
    Write-Host "Groups in Source not in Target: $($groupsInSourceNotInTarget.Count)"
    Write-Host "--------------------------------"
    foreach ($grp1 in $groupsInSourceNotInTarget) {
        Write-Host "    $($grp1.name)"
    }
    Write-Host "--------------------------------"
    Write-Host " "

    $groupsInTargetNotInSource = $targetGroups | Where-Object { $_.name -notin $sourceGroups.name }
    Write-Host "Groups in Target not in Source: $($groupsInTargetNotInSource.Count)"
    Write-Host "--------------------------------"
    foreach ($grp2 in $groupsInTargetNotInSource) {
        Write-Host "    $($grp2.name)"
    }
    Write-Host "--------------------------------"
    Write-Host " "

    $jsonString = ""
    foreach ($sourceGroup in $sourceGroups) {

        $sourceGroupName = $sourceGroup.name
        $sourceGroupId = $sourceGroup.id

        Write-Host "--------------------------------------------------------------------------------------"
        Write-Host "--- Group $($sourceGroupName) - $($sourceGroupId) ---"
        Write-Host "--------------------------------------------------------------------------------------"
        $targetGroup = $targetGroups | Where-Object { $_.Name -ieq $sourceGroup.Name }
        
        if($targetGroup) {
            Write-Host "-------------------- "
            Write-Host "--- User Members --- "
            Write-Host "-------------------- "

            Write-Host "Source Group [$($sourceGroup.Name)] UserMembers Count: $($sourceGroup.UserMembers.Count)"
            Write-Host "------------"
            foreach ($s_userMember in $sourceGroup.UserMembers) {
                Write-Host "    $($s_userMember.Name), $($s_userMember.Id)"
            }
            Write-Host "------------"
            Write-Host " "

            Write-Host "Target Group [$($targetGroup.Name)] UserMembers Count: $($targetGroup.UserMembers.Count)"
            Write-Host "------------"
            foreach ($t_userMember in $targetGroup.UserMembers) {
                Write-Host "    $($t_userMember.Name), $($t_userMember.Id)"
            }
            Write-Host "------------"
            Write-Host " "
            Write-Host " "

            Write-Host "--------------------- "
            Write-Host "--- Group Members --- "
            Write-Host "--------------------- "

            Write-Host "Source Group [$($sourceGroup.Name)] GroupMembers Count: $($sourceGroup.GroupMembers.Count)"
            Write-Host "------------"
            foreach ($s_groupMember in $sourceGroup.GroupMembers) {
                Write-Host "    $($s_groupMember.Name), $($s_groupMember.Id)"
            }
            Write-Host "------------"
            Write-Host " "

            Write-Host "Target Group [$($targetGroup.Name)] GroupMembers Count: $($targetGroup.GroupMembers.Count)"
            Write-Host "------------"
            foreach ($t_groupMember in $targetGroup.GroupMembers) {
                Write-Host "    $($t_groupMember.Name), $($t_groupMember.Id)"
            }
            Write-Host "------------"
            Write-Host " "
        }
       
        $jsonString += "`n"
        $jsonString += "--------------------------"
        $jsonString += "--- Source Group JSON --- "
        $jsonString += "--------------------------"

        $sourceGroupJson = ConvertTo-Json -Depth 100 $sourceGroup
        $jsonString += $sourceGroupJson 
       
        $jsonString += "`n"
        $jsonString += "`n"
        $jsonString += "--------------------------"
        $jsonString += "--- Target Group JSON --- "
        $jsonString += "--------------------------"
        $sourceGroupJson = ConvertTo-Json -Depth 100 $targetGroup
        $jsonString += $sourceGroupJson
        $jsonString += "`n"
        $jsonString += "--------------------------------------------------"
        $jsonString += "`n"
    }

    Write-Host " "
    Write-Host "-------------------------------------------------------"
    Write-Host "--- Source Group to Target Groups JSON Comparisons --- "
    Write-Host "-------------------------------------------------------"
    Write-Host $jsonString
    Write-Host " "
    Write-Host " "
    Write-Host "--------------------------------------------------------------------------------------"

    Stop-Transcript
