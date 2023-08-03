
Using Module ".\Migrate-ADO-Common.psm1"

function Start-ADOBuildEnvironmentsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)] 
        [String]$SourcePAT,
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $TRUE)] 
        [String]$TargetPAT,

        [Parameter (Mandatory = $FALSE)]
        [Bool]$ReplacePipelinePermissions = $FALSE
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate build queries from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '--------------------------------'
        Write-Log -Message '-- Migrate Build Environments --'
        Write-Log -Message '--------------------------------'
        Write-Log -Message ' '

        Write-Log -Message "Get Source Project to do source lookups.."
        $sourceProject = Get-ADOProjects -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders
        Write-Log -Message "Get target Project to do source lookups.."
        $targetProject = Get-ADOProjects -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders

        Write-Log -Message "Get Source Groups to do source lookups.."
        $sourceGroups = Get-ADOGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName -PersonalAccessToken $SourcePAT -GetGroupMembers $FALSE
        Write-Log -Message "Get Target Groups to do source lookups.."
        $targetGroups = Get-ADOGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName -PersonalAccessToken $TargetPAT -GetGroupMembers $FALSE

        Write-Log -Message "Get Source Environments.."
        $sourceEnvironments = Get-BuildEnvironments -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -ProjectId $sourceProject.Id -Top 1000000
        Write-Log -Message "Get Target Environments.."
        $targetEnvironments = Get-BuildEnvironments -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId $targetProject.Id -Top 1000000

        Write-Log -Message "Get Target Pipelines to do source lookups.."
        $targetPipelines = Get-Pipelines -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName

        $newBuildEnvironments = @()
        foreach ($sourceEnvironment in $sourceEnvironments) {
            if ($null -ne ($targetEnvironments | Where-Object { $_.Name -ieq $sourceEnvironment.Name })) {
                Write-Log -Message "Build environment [$($sourceEnvironment.Name)] already exists in target.. "
                $newBuildEnvironments += $sourceEnvironment
                continue
            }

            Write-Log -Message "Attempting to create [$($sourceEnvironment.Name)] in target.. "
            try {
                Write-Log -Message " "
                Write-Log -Message "Source Environment ID: $($sourceEnvironment.Name)"
                Write-Log -Message "Source Environment ID: $($sourceEnvironment.Id)"
                Write-Log -Message " "

                New-BuildEnvironment -ProjectName $TargetProjectName -OrgName $TargetOrgName  -Headers $Targetheaders -Environment $sourceEnvironment -ProjectId $targetProject.Id

                Write-Log -Message "Done!" -LogLevel SUCCESS
                $newBuildEnvironments += $sourceEnvironment
            } catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
            }
        }

        Write-Log -Message "Reload Target Environments to get any newly created ones.."
        $targetEnvironments = Get-BuildEnvironments -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId $targetProject.Id -Top 1000000

        foreach ($newEnvironment in $newBuildEnvironments) {
            Write-Log -Message "------------------------------------------------------------------------------------------------------------------"
            Write-Log -Message "----- Processing  Environment $($newEnvironment.name) -----"
            Write-Log -Message "------------------------------------------------------------------------------------------------------------------"

            # Get and Update Role Assignments
            $sourceRoleAssignments = Get-BuildEnvironmentRoleAssignments -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -ProjectId $sourceProject.Id -EnvironmentId $newEnvironment.Id
            $targetEnvironment = $targetEnvironments | Where-Object { $_.Name -ieq $newEnvironment.Name }
            $targetRoleAssignments = $NULL
            if($NULL -ne $targetEnvironment) {
                Write-Log -Message "--- User permissions --- "
                $targetRoleAssignments = Get-BuildEnvironmentRoleAssignments -ProjectName $targetProjectName -OrgName $targetOrgName -Headers $targetheaders -ProjectId $targetProject.Id -EnvironmentId $targetEnvironment.Id
                
                foreach($roleAssignment in $sourceRoleAssignments) { 
                    # Search Users for the roleAssignment's Identity Id 
                    $roleAssignmentIdentityId = $null
    
                    $sourceIdentity = Get-IdentityInfo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -IdentityId $roleAssignment.Identity.Id -SubjectDescriptor $NULL
                    $targetIdentity = Get-IdentityInfo -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -IdentityId $NULL -SubjectDescriptor $sourceIdentity.subjectDescriptor
    
                    if ($null -ne $targetIdentity) {
                        $roleAssignmentIdentityId = $targetIdentity.Id
                    } else {
                        #Search Groups for the roleAssignment's Identity Id 
                        $existingGroup = $sourceGroups | Where-Object { $_.Id -ceq $roleAssignment.Identity.Id }
                        $migratedGroup = $targetGroups | Where-Object { $_.Name -ceq $existingGroup.Name }
                        if ($null -ne $migratedGroup) {
                            $roleAssignmentIdentityId = $migratedGroup.Id
                        }
                    }
    
                    if($NULL -ne $roleAssignmentIdentityId) {
                        # Try to find RoleAssignment in target
                        $targetRoleAssignment = $targetRoleAssignments | Where-Object { ($_.identity.id -eq $roleAssignmentIdentityId) -and ($_.role.name -eq $roleAssignment.role.name) }
    
                        if ($NULL -ne $targetRoleAssignment) {
                            Write-Log -Message "Role Assignment [[ $($roleAssignment.Identity.displayName) / $($roleAssignmentIdentityId) / $($roleAssignment.role.name) ]] already exists in target.. "
                        } else {
                            try {
                                $data = @{
                                    "roleName"   = $roleAssignment.Role.Name
                                    "userId"     = $roleAssignmentIdentityId 
                                }
            
                                $scope = $roleAssignment.Role.Scope
                                Write-Log -Message " "
                                Write-Log -Message "Create new Role Assignment $($roleAssignmentIdentityId) / $($roleAssignment.role.name) in target.."
                                Write-Log -Message "Scope: $scope"
                                Write-Log -Message "Source Environment ID: $($newEnvironment.Id)"
                                Write-Log -Message "Source Identity Display Name: $($roleAssignment.Identity.displayName)"
                                Write-Log -Message "Source Identity Id: $($roleAssignment.Identity.Id)"
                                Write-Log -Message "Source Role Name: $($roleAssignment.role.name)"
                                Write-Log -Message "Target Identity Id: $($roleAssignmentIdentityId)"
                                Write-Log -Message "Target Role Name: $($roleAssignment.role.name)"
                                Write-Log -Message "Target Environment ID: $($targetEnvironment.Id)"
                                Write-Log -Message "Target Org Name: $TargetOrgName"
                                Write-Log -Message "Target Project ID: $($targetProject.Id)"
                                Write-Log -Message " "

                                Set-BuildEnvironmentRoleAssignment -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId $targetProject.Id -EnvironmentId $targetEnvironment.Id -ScopeId $scope -RoleAssignment $data
                            } catch {
                                Write-Log -Message "FAILED to Update Build Environment User Permissions ROle Assignment!" -LogLevel ERROR
                                Write-Log -Message $_.Exception -LogLevel ERROR
                                try {
                                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                                } catch {}
                            }
                        }
    
                    } else {
                        Write-Log -Message "Unable to locate Identity $($roleAssignment.Identity.displayName) in target, unable to set role assignment Role Assignment $($roleAssignment.identity.id) / $($roleAssignment.role.name) in target.. " -LogLevel DEBUG
                    }
                }


    
                # Get and Update pipeline permissions
                Write-Log -Message "--- Pipline permissions --- "

                Write-Log -Message "Get Source Pipline permissions.."
                $sourcePipelinePermissions = Get-BuildEnvironmentPipelinePermissions -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -EnvironmentId $newEnvironment.Id
                $targetPipelinePermissions = Get-BuildEnvironmentPipelinePermissions -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -EnvironmentId $targetEnvironment.Id

                $newPipelinePermissions = @()
                if ($TRUE -eq $ReplacePipelinePermissions) {
                    $newPipelinePermissions = $targetPipelinePermissions.Pipelines.Clone()
                    $newPipelinePermissions = @($newPipelinePermissions | Where-Object { $_.Id -notin $sourcePipelinePermissions.Pipelines.Id })

                    # Set to remove all items that are not in the Source Pipeline Permissions 
                    foreach ($permission in $newPipelinePermissions) {
                        $permission.PSObject.Members.Remove("authorizedBy")
                        $permission.PSObject.Members.Remove("authorizedOn")
                        $permission.Authorized = $FALSE
                    }
                }

                foreach ($pipelinePermission in $sourcePipelinePermissions.Pipelines) {
                    $sourcePipeline = Get-Pipeline -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName -DefinitionId $pipelinePermission.Id
                    $targetPipeline = ($targetPipelines | Where-Object {$_.Name -ceq $sourcePipeline.Name})
                    
                    if ($NULL -ne $targetPipeline) {
                        $object = [PSCustomObject]@{
                            id          = $targetPipeline.Id
                            authorized  = $pipelinePermission.Authorized
                          }
                        $newPipelinePermissions += $object
                    } else {
                        Write-Log -Message "Unable to map Source Pipeline ID [$($pipelinePermission.Id)] to a Target pipeline in order to set a Environment pipeline permission.." -LogLevel ERROR
                    }
                }

                try {
                    Write-Log -Message "Update Target Pipline permissions.."
                    
                    Write-Log -Message " "
                    Write-Log -Message "Target Environment Id: $($targetEnvironment.Id)"
                    Write-Log -Message "PipelinePermissions: $(ConvertTo-Json -Depth 100 $newPipelinePermissions)"
                    
                    Set-BuildEnvironmentPipelinePermissions -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -EnvironmentId $targetEnvironment.Id -PipelinePermissions $newPipelinePermissions
                } catch {
                    Write-Log -Message "FAILED to Update Build Environment User Permissions ROle Assignment!" -LogLevel ERROR
                    Write-Log -Message $_.Exception -LogLevel ERROR
                    try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                    } catch {}
                }
            }
            Write-Log -Message "------------------------------------------------------------------------------------------------------------------"
        }
    }
}

function Get-BuildEnvironments {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectId,

        [Parameter (Mandatory = $False)]
        [Int32]$Top = 0

    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        if($Top -lt 0) {$Top = 0}

        $url = "https://dev.azure.com/$OrgName/$ProjectId/_apis/distributedtask/environments?api-version=7.1-preview"

        if($top -gt 0) {
            $url = "https://dev.azure.com/$OrgName/$ProjectId/_apis/distributedtask/environments?`$top=$($Top)&api-version=7.1-preview"
        }

    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        return $results.value
    }
}

function Get-BuildEnvironmentRoleAssignments {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectId,

        [Parameter (Mandatory = $TRUE)]
        [String]$EnvironmentId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/_apis/securityroles/scopes/distributedtask.environmentreferencerole/roleassignments/resources/$($ProjectId)_$($EnvironmentId)"

        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        return $results.value
    }
}


function Get-IdentityInfo {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [String]$IdentityId,

        [Parameter (Mandatory = $FALSE)]
        [String]$SubjectDescriptor
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://vssps.dev.azure.com/$OrgName/_apis/identities?identityIds=$($IdentityId)&subjectDescriptors=$($SubjectDescriptor)&api-version=7.0"

        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        return $results.Value
    }
}


function Set-BuildEnvironmentRoleAssignment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectId,

        [Parameter (Mandatory = $TRUE)]
        [String]$EnvironmentId,

        [Parameter (Mandatory = $TRUE)]
        [String]$ScopeId,

        [Parameter (Mandatory = $TRUE)]
        [Object]$RoleAssignment
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/_apis/securityroles/scopes/$ScopeId/roleassignments/resources/$($ProjectId)_$($EnvironmentId)?api-version=6.1-preview.1"

        $roleAssignments = @() 
        $roleAssignments += $RoleAssignment
        $body = ConvertTo-Json -Depth 100 $roleAssignments

        $results = Invoke-RestMethod -Method PUT -uri $url -Headers $Headers -Body $body -ContentType "application/json"

        return $results
    }
}

function Get-BuildEnvironmentPipelinePermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$EnvironmentId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/pipelines/pipelinePermissions/environment/$EnvironmentId"
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        return $results
    }
}

function Set-BuildEnvironmentPipelinePermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$EnvironmentId,

        [Parameter (Mandatory = $TRUE)]
        [AllowEmptyCollection()]
        [Object[]]$PipelinePermissions
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/pipelines/pipelinePermissions/environment/$($EnvironmentId)?api-version=7.0-preview.1"
        
        $permissions = @() 
        $permissions += $PipelinePermissions
       
        $body = @{
            "pipelines" = $permissions
        }
        $body = ConvertTo-Json -Depth 100 $body

        $results = Invoke-RestMethod -Method PATCH -uri $url -Headers $Headers -Body $body -ContentType "application/json"

        return $results.pipelines
    }
}

function New-BuildEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Object]$environment,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/$ProjectId/_apis/distributedtask/environments?api-version=6.1-preview.1"
        
        $body = @{
            "name"          = $environment.Name
            "description"   = $environment.Description
        } | ConvertTo-Json

        $results = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    
        return $results
    }
}