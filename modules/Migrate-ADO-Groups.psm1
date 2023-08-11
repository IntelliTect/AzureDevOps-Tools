
Using Module ".\Migrate-ADO-Common.psm1"

function Start-ADOGroupsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourcePAT,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetPAT
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate groups & members from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '--------------------'
        Write-Log -Message '-- Migrate Groups --'
        Write-Log -Message '--------------------'
        Write-Log -Message ' '

        Write-Log -Message 'Get ADO Groups'
        $sourceGroups = Get-ADOGroups `
            -OrgName $SourceOrgName `
            -ProjectName $SourceProjectName `
            -PersonalAccessToken $SourcePAT `
            -GroupDisplayName $GroupDisplayName

        $targetGroups = Get-ADOGroups `
            -OrgName $TargetOrgName `
            -ProjectName $TargetProjectName `
            -PersonalAccessToken $TargetPAT 

        Write-Log -Message 'Migrate ADO Groups'
        Push-ADOGroups `
            -PersonalAccessToken $TargetPAT `
            -OrgName $TargetOrgName `
            -ProjectName $TargetProjectName `
            -SourceGroups $sourceGroups `
            -TargetGroups $targetGroups
    }
}

function Push-ADOGroups {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Object]$SourceGroups, 

        [Parameter (Mandatory = $TRUE)]
        [Object]$TargetGroups
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        # Create all groups before adding members to each group
        [ADO_Group[]]$processSourceGroups = @()
        foreach ($group in $SourceGroups) {
            $existingGroup = $TargetGroups | Where-Object { $_.Name -ieq $group.Name }
            if ($null -ine $existingGroup) {
                Write-Log -Message "Group [$($group.Name)] already exists in target.. "
                $processSourceGroups += $group
                continue
            }

            Write-Log -Message "Creating New Group [$($group.Name)] in target.. "
            $result = New-ADOGroup `
                -PersonalAccessToken $PersonalAccessToken `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -GroupName $group.Name `
                -GroupDescription $group.Description

             # If we created new target Groups then add the Group the targetGroups to do lookups for populating Members
            $newGroup = [ADO_Group]::new($result.NewGroup.originId, $result.NewGroup.displayName, $result.NewGroup.principalName, $result.NewGroup.description, $result.NewGroup.descriptor)
            $targetGroup.Add($newGroup)
            
            if ($null -ine $result.NewGroup) {
                $processSourceGroups += $result.NewGroup
            }
        }

        foreach ($processGroup in $processSourceGroups) {
            [ADO_Group]$targetGroup = $TargetGroups | Where-Object { $_.Name -ieq $processGroup.Name }
            
            Push-GroupMembers `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -PersonalAccessToken $PersonalAccessToken `
                -SourceGroup $processGroup `
                -TargetGroup $targetGroup
        }
    }
}

function New-ADOGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$GroupName,

        [Parameter (Mandatory = $FALSE)]
        [String]$GroupDescription = ""
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        $GroupDescription = $GroupDescription.Replace('"',"'")
        if ($Group.Description) {
            $result = az devops security group create --name $GroupName --description $GroupDescription --detect $false 2>"$env:temp\err_group1.txt"
            $ers = Get-Content "$env:temp\err_group1.txt"
            if ($ers) { Write-Log -Message $ers -LogLevel ERROR }
            Remove-Item -Path "$env:temp\err_group1.txt"
        }
        else {
            $result = az devops security group create --name $GroupName --detect $false 2>"$env:temp\err_group2.txt"
            $ers = Get-Content "$env:temp\err_group2.txt"
            if ($ers) { Write-Log -Message $ers -LogLevel ERROR }
            Remove-Item -Path "$env:temp\err_group2.txt"
        }
        if (!$result) {
            Write-Log -Message "Could not create a new group with name '$($GroupName)'. The group name may be reserved by the system." -LogLevel ERROR
            return @{
                "NewGroup" = $null
            }
        }
        $result = $result | ConvertFrom-JSON
        $newGroup = [ADO_Group]::new($result.originId, $result.displayName, $result.principalName, $result.description, $result.descriptor)
        return @{
            "NewGroup" = $newGroup
        }
    }
}

function Push-GroupMembers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [ADO_Group]$SourceGroup,

        [Parameter (Mandatory = $FALSE)]
        [ADO_Group]$TargetGroup = $null
    )
    if ($PSCmdlet.ShouldProcess("$GroupDisplayName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        # Add user members
        foreach ($userMember in $SourceGroup.UserMembers) {
            if ($null -ne ($TargetGroup.UserMembers | Where-Object { $_.PrincipalName -ieq $userMember.PrincipalName } )) {
                Write-Log -Message "User Member [$($userMember.Name)] already exists in target group [$($SourceGroup.Name)].. "
                continue
            }

            try{
                az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $userMember.PrincipalName --detect $false --debug --verbose 2>"$env:temp\error_group1.txt" 3>"$env:temp\debug_group1.txt" 4>"$env:temp\verbos_group1.txt"
                $error_message = Get-Content "$env:temp\error_group1.txt"
                $debug_message = Get-Content "$env:temp\debug_group1.txt"
                $verbos_message = Get-Content "$env:temp\verbos_group1.txt"
                if ($error_message) {Write-Log -Message $error_message -LogLevel ERROR}
                if ($debug_message) {Write-Log -Message $debug_message -LogLevel ERROR}
                if ($debug_message) {Write-Log -Message $verbos_message -LogLevel ERROR}
                Remove-Item -Path "$env:temp\error_group1.txt"
                Remove-Item -Path "$env:temp\debug_group1.txt"
                Remove-Item -Path "$env:temp\verbos_group1.txt"

            } catch {
                Write-Log -Message $_.Exception.Message -LogLevel ERROR
            }
            
        }
        # Add group members
        foreach ($groupMember in $SourceGroup.GroupMembers) {
            try {
                $groupOnTarget = Get-ADOGroups `
                    -OrgName $OrgName `
                    -ProjectName $ProjectName `
                    -PersonalAccessToken $PersonalAccessToken `
                    -GroupDisplayName $groupMember.Name

                if ($null -ne ($TargetGroup.GroupMembers | Where-Object { $_.Name -ieq $groupMember.Name } )) {
                    Write-Log -Message "Group Member [$($groupMember.Name)] already exists in target group [$($SourceGroup.Name)].. "
                    continue
                }
                az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $groupOnTarget.PrincipalName --detect $false --debug --verbose 2>"$env:temp\error_group2.txt" 3>"$env:temp\debug_group2.txt" 4>"$env:temp\verbos_group2.txt"
                $error_message = Get-Content "$env:temp\error_group2.txt"
                $debug_message = Get-Content "$env:temp\debug_group2.txt"
                $verbos_message = Get-Content "$env:temp\verbos_group2.txt"
                if ($error_message) {Write-Log -Message $error_message -LogLevel ERROR}
                if ($debug_message) {Write-Log -Message $debug_message -LogLevel ERROR}
                if ($debug_message) {Write-Log -Message $verbos_message -LogLevel ERROR}
                Remove-Item -Path "$env:temp\error_group2.txt"
                Remove-Item -Path "$env:temp\debug_group2.txt"
                Remove-Item -Path "$env:temp\verbos_group2.txt"
            } catch {
                Write-Log -Message $_.Exception.Message -LogLevel ERROR
            }
        }
    }
}