
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
        [String]$TargetPAT,

        [Parameter (Mandatory = $FALSE)]
        [String]$VerboseOutput = $FALSE
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate groups & members from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '------------------------'
        Write-Log -Message '-- Migrate ADO Groups --'
        Write-Log -Message '------------------------'
        Write-Log -Message ' '

        Write-Log -Message 'Get Source ADO Groups'
        $sourceGroups = Get-ADOGroups `
            -OrgName $SourceOrgName `
            -ProjectName $SourceProjectName `
            -PersonalAccessToken $SourcePAT `
            -GroupDisplayName $GroupDisplayName

        $sourceGroupNames = $sourceGroups | Select-Object -ExpandProperty name
        Write-Log "Group Display Name for getting source groups: $GroupDisplayName"
        Write-Log "Source group names: $($sourceGroupNames -join ',')"
        Write-Log -Message 'Get target ADO Groups'
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
            -TargetGroups $targetGroups `
            -VerboseOutput $VerboseOutput
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
        [Object]$TargetGroups,

        [Parameter (Mandatory = $FALSE)]
        [String]$VerboseOutput = $FALSE
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
                -GroupDescription $group.Description `
                -VerboseOutput $VerboseOutput

            # If we created new target Group then add the Group to the targetGroups to do lookups for populating Members
            if ($null -ne $result.NewGroup) {
                $newGroup = [ADO_Group]::new($result.NewGroup.originId, $result.NewGroup.displayName, $result.NewGroup.principalName, $result.NewGroup.description, $result.NewGroup.descriptor)
                $targetGroups += $newGroup
                $processSourceGroups += $group
            } else {
                Write-Log -Message "unable to Create New Group [$($group.Name)] in target, it may need to be migrated manually.. "
            }
        }

        foreach ($processGroup in $processSourceGroups) {
            [ADO_Group]$targetGroup = $TargetGroups | Where-Object { $_.Name -ieq $processGroup.Name }
            
            Push-GroupMembers `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -PersonalAccessToken $PersonalAccessToken `
                -SourceGroup $processGroup `
                -TargetGroup $targetGroup `
                -VerboseOutput $VerboseOutput
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
        [String]$GroupDescription = "",

        [Parameter (Mandatory = $FALSE)]
        [String]$VerboseOutput = $FALSE
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        $GroupDescription = $GroupDescription.Replace('"',"'")

        if ($Group.Description) {
            if($VerboseOutput -eq $TRUE) {
                $result = az devops security group create --name $GroupName --description $GroupDescription --detect $false --debug --verbose
            } else {
                $result = az devops security group create --name $GroupName --description $GroupDescription --detect $false 
            }
        }
        else {
            if($VerboseOutput -eq $TRUE) {
                $result = az devops security group create --name $GroupName --detect $false --debug --verbose
            } else {
                $result = az devops security group create --name $GroupName --detect $false 
            }
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
        [ADO_Group]$TargetGroup = $null,

        [Parameter (Mandatory = $FALSE)]
        [String]$VerboseOutput = $FALSE
    )
    if ($PSCmdlet.ShouldProcess("$GroupDisplayName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        # Add user members
        foreach ($userMember in $SourceGroup.UserMembers) {
            try {
                if ($null -ne ($TargetGroup.UserMembers | Where-Object { $_.PrincipalName -ieq $userMember.PrincipalName } )) {
                    Write-Log -Message "User Member [$($userMember.Name)] already exists in target group [$($SourceGroup.Name)].. "
                    continue
                }
            
                Write-Log -Message "Adding User Member [$($userMember.Name)] in target group [$($SourceGroup.Name)].. "
                if($VerboseOutput -eq $TRUE) {
                    az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $userMember.PrincipalName --detect $false --debug --verbose
                } else {
                    az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $userMember.PrincipalName --detect $false 
                }
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
 
                Write-Log "Group on target: $groupOnTarget"                
                              

                if ($null -ne ($TargetGroup.GroupMembers | Where-Object { $_.Name -ieq $groupMember.Name } )) {
                    Write-Log -Message "Group Member [$($groupMember.Name)] already exists in target group [$($SourceGroup.Name)].. "
                    continue
                }

                Write-Log -Message "Adding Group Member [$($groupMember.Name)] in target group [$($SourceGroup.Name)].. "
                if($VerboseOutput -eq $TRUE) {
                    Write-Log "Group on target principal name: $($groupOnTarget.PrincipalName)"
                    az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $groupOnTarget.PrincipalName --detect $false --debug --verbose
                } else {
                    Write-Log "Group on target Descriptior: $($groupOnTarget.Descriptor)"
                    az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $groupOnTarget.Descriptor --detect $false                     
                }
            } catch {
                Write-Log -Message $_.Exception.Message -LogLevel ERROR
            }
        }
    }
}