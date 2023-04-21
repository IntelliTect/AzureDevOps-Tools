class ADO_Group {
    [String]$Id
    [String]$Name
    [String]$PrincipalName
    [String]$Description
    [String]$Descriptor
    [ADO_GroupMember[]]$UserMembers = @()
    [ADO_Group[]]$GroupMembers = @()
    
    ADO_Group(
        [String]$id,
        [String]$name,
        [String]$principalName,
        [String]$description,
        [String]$descriptor
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.PrincipalName = $principalName
        $this.Description = $description
        $this.Descriptor = $descriptor
    }
}

class ADO_GroupMember {
    [String]$Id
    [String]$Name
    [String]$PrincipalName
    
    ADO_GroupMember(
        [String]$id,
        [String]$name,
        [String]$principalName
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.PrincipalName = $principalName
    }
}

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
        $groups = Get-ADOGroups `
            -OrgName $SourceOrgName `
            -ProjectName $SourceProjectName `
            -PersonalAccessToken $SourcePAT

        Write-Log -Message 'Migrate ADO Groups'
        Push-ADOGroups `
            -PersonalAccessToken $TargetPAT `
            -OrgName $TargetOrgName `
            -ProjectName $TargetProjectName `
            -Groups $groups
    }
}

function Get-ADOGroups {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $FALSE)]
        [String]$GroupDisplayName
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        if ($GroupDisplayName) {
            $groups = az devops security group list --query "graphGroups[?displayName == '$($GroupDisplayName)']" --detect $false | ConvertFrom-Json
            if (!$groups) {
                throw "Group called '$GroupDisplayName' cannot be found in '$OrgName/$ProjectName'"
            }
        }
        else {
            $groups = (az devops security group list --detect $false | ConvertFrom-Json).graphGroups
        }
        
        [ADO_Group[]]$groupsFound = @() 
        foreach ($group in $groups) {
            $group = [ADO_Group]::new($group.originId, $group.displayName, $group.principalName, $group.description, $group.descriptor)
            $members = Get-ADOGroupMembers `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -PersonalAccessToken $PersonalAccessToken `
                -GroupDescriptor $group.Descriptor

            $group.GroupMembers = $members.GroupGroupMembers
            $group.UserMembers = $members.GroupUserMembers

            $groupsFound += $group
        }
        return $groupsFound
    }
}

function Get-ADOGroupMembers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [String]$GroupDescriptor
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        [ADO_GroupMember[]]$GroupUserMembers = @()
        [ADO_Group[]]$GroupGroupMembers = @()
        $members = az devops security group membership list --id $GroupDescriptor --detect $false | ConvertFrom-Json
        if ($members) {
            $descriptors = $members | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
    
            foreach ($descriptor in $descriptors) {
                $member = $members.$descriptor
                if ($member.subjectKind -eq "user") {
                    $GroupUserMembers += [ADO_GroupMember]::new($member.originId, $member.displayName, $member.principalName)
                }
                else {
                    $GroupGroupMembers += [ADO_Group]::new($member.originId, $member.displayName, $member.principalName, $member.description, $member.descriptor)
                }
            }
        }

        return @{
            "GroupUserMembers"  = $GroupUserMembers
            "GroupGroupMembers" = $GroupGroupMembers
        }
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
        [ADO_Group[]]$Groups
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        $targetGroups = Get-ADOGroups `
            -OrgName $OrgName `
            -ProjectName $ProjectName `
            -PersonalAccessToken $PersonalAccessToken

        # Create all groups before adding members to each group
        [ADO_Group[]]$newTargetGroups = @()
        foreach ($group in $Groups) {
            $existingGroup = $targetGroups | Where-Object { $_.Name -ieq $group.Name }
            if ($null -ine $existingGroup) {
                Write-Log -Message "Group [$($group.Name)] already exists in target.. "
                $newTargetGroups += $existingGroup
                continue
            }
            $result = New-ADOGroup `
                -PersonalAccessToken $PersonalAccessToken `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -GroupName $group.Name `
                -GroupDescription $group.Description
            
            if ($null -ine $result.NewGroup) {
                $newTargetGroups += $result.NewGroup
            }
        }

        foreach ($newTargetGroup in $newTargetGroups) {
            [ADO_Group]$sourceGroup = $Groups | Where-Object { $_.Name -ieq $newTargetGroup.Name }
            Push-GroupMembers `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -PersonalAccessToken $PersonalAccessToken `
                -SourceGroup $sourceGroup `
                -TargetGroup $newTargetGroup
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

        if ($Group.Description) {
            $result = az devops security group create --name $GroupName --description $GroupDescription --detect $false
        }
        else {
            $result = az devops security group create --name $GroupName --detect $false
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
                Write-Log -Message "Member [$($userMember.Name)] already exists in target group.. "
                continue
            }
            az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $userMember.PrincipalName --detect $false --debug --verbose
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
                    Write-Log -Message "Member [$($groupMember.Name)] already exists in target group.. "
                    continue
                }
                az devops security group membership add --group-id $TargetGroup.Descriptor --member-id $groupOnTarget.PrincipalName --detect $false --debug --verbose
            }
            catch {
                Write-Log -Message $_.Exception.Message -LogLevel ERROR
            }
        }
    }
}