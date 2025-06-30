Using Module "..\modules\Migrate-ADO-Common.psm1"
Using Module "..\modules\Migrate-ADO-ServiceConnections.psm1"
Using Module "..\modules\Migrate-ADO-BuildEnvironments.psm1"

function Start-ClassicBuildPipelinesMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $FALSE)]
        [Boolean]$MigrateOnlyProblematicPipelines = $true
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        
        Write-Log -Message ' '
        Write-Log -Message '-------------------------------------------------------------'
        Write-Log -Message '-- Migrate Classic Build Pipelines (Exception Cases Only) --'
        Write-Log -Message '-------------------------------------------------------------'
        Write-Log -Message ' '

        $sourcePipelines = Get-Pipelines -Headers $SourceHeaders -ProjectName $SourceProjectName -OrgName $SourceOrgName
        $targetPipelines = Get-Pipelines -Headers $TargetHeaders -ProjectName $targetProjectName -OrgName $TargetOrgName
        
        $targetPipelineNames = $targetPipelines | Select-Object -ExpandProperty name

        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $sourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $TargetHeaders
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders
        $targetAgentPoolsUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/distributedtask/queues?api-version=7.1"
        $targetAgentPools = Invoke-RestMethod -Method GET -uri $targetAgentPoolsUrl -Headers $TargetHeaders

        $sourceTaskGroups = Get-TaskGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName `
            -Headers $SourceHeaders
        
        Move-TaskGroups -SourceTaskGroups $sourceTaskGroups.value -TargetProjectName $TargetProjectName `
            -TargetOrgName $TargetOrgName -TargetHeaders $TargetHeaders

        $targetTaskGroups = Get-TaskGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName `
            -Headers $TargetHeaders

        $targetRepos = Get-Repos -projectName $TargetProjectName -orgName $TargetOrgName -headers $TargetHeaders

        $pipelinesToMigrate = $sourcePipelines | Where-Object { $targetPipelineNames -notcontains $_.name }
        
        $CreatedPipelinesCount = 0 
        $FailedPipelinesCount = 0
        foreach ($pipeline in $pipelinesToMigrate) {
            try {
                $CreatePipeline = $false
    
                $definition = Get-BuildDefinition -OrgName $SourceOrgName -ProjectName $SourceProjectName `
                    -Headers $SourceHeaders -DefinitionId $pipeline.id
                
                foreach ($phase in $definition.process.phases) {
                    foreach ($step in $phase.steps) {
                        #If the service connection ID is located, the we have to swap the value for the appropriate target service connection
                        $ServiceConnectionIdforRunningFortifyScan = $step.inputs.cloudScanfortifyServerName
                        if ($step.inputs.externalEndpoints) {
                            $ExternalEndpointsServiceConnectionIds = $step.inputs.externalEndpoints -split ","
    
                            $endpointsString = ""
                            forEach ($endpoint in $ExternalEndpointsServiceConnectionIds) {
                                if ($endpoint -ne "") {
                                    $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                                    $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                                    $endpointsString += ",$targetServiceConnectionId"                                
                                }                            
                            }
                            $step.inputs.externalEndpoints = $endpointsString
                        }
                        
                        $AzureServiceConnectionId = $step.inputs.azureSubscription
                        $ConnectedServiceNameARMServiceConnectionId = $step.inputs.connectedServiceNameARM
                        if ($null -ne $ServiceConnectionIdforRunningFortifyScan) {
                            
                            $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                            $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                            $step.inputs.cloudScanfortifyServerName = $targetServiceConnectionId
                            if ($MigrateOnlyProblematicPipelines) {
                                $CreatePipeline = $true
                            }
                        }
                        
                        if ($MigrateOnlyProblematicPipelines) {
                            $CreatePipeline = $true
                        }
                        if ($null -ne $AzureServiceConnectionId) {
                            $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                            $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                            $step.inputs.azureSubscription = $targetServiceConnectionId
                            if ($MigrateOnlyProblematicPipelines) {
                                $CreatePipeline = $true
                            }
                        }
                        if ($null -ne $ConnectedServiceNameARMServiceConnectionId) {
                            $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ConnectedServiceNameARMServiceConnectionId } | Select-Object -ExpandProperty name
                            $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                            $step.inputs.connectedServiceNameARM = $targetServiceConnectionId
                            if ($MigrateOnlyProblematicPipelines) {
                                $CreatePipeline = $true
                            }
                        }          
                    }
                }
                if (!$MigrateOnlyProblematicPipelines -OR $CreatePipeline -eq $true) {
                    Write-Log "Creating Pipeline $($definition.name) using PowerShell due to hardcoded a harcoded service connection id input"
                    $targetRepo = $TargetRepos | Where-Object { $_.name -eq $definition.repository.name }

                    if ($null -eq $targetRepo) {
                        Write-Warning -Message "Unable to create pipeline: $($definition.name) because missing repo: $($definition.repository.name)"
                        Write-Warning -Message "Most likey caused by repo being disabled."
                        continue
                    }

                    $targetAgentPool = $targetAgentPools.value | Where-Object { $_.name -eq $definition.queue.name }
                    
                    $definition.repository.id = $targetRepo.id
                    $definition.repository.url = "https://dev.azure.com/$targetOrgName/$targetProjectName/_git/$repoName"
                    $definition.project.id = $targetProject.id
                    $definition.queue.id = $targetAgentPool.id
                    $definition.queue.url = "https://dev.azure.com/$targetOrgName/_apis/build/Queues/$($targetAgentPool.id)"
                    $definition.queue.pool.id = $targetAgentPool.pool.id
    
                    forEach ($phase in $definition.process.phases) {
                        if ($null -ne $phase.target.queue) {
                            $phase.target.queue.id = $targetAgentPool.id
                            $phase.target.queue.url = "https://dev.azure.com/$targetOrgName/_apis/build/Queues/$($targetAgentPool.id)"
                        }

                        foreach ($step in $phase.steps) {
                            $step.task.id = Get-TargetTaskId -SourceTaskGroups $sourceTaskGroups.value -TargetTaskGroups `
                                $targetTaskGroups.value -SourceTaskGroupId $step.task.id
                        }
                    }
    
                    if ($null -ne $definition.queue.pool.isHosted) {
                        $definition.queue.pool.isHosted = $targetAgentPool.pool.isHosted
                    }

                    $newPipeline = New-Pipeline -PipelineDefinition $definition -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
                    if ($null -ne $newPipeline) {
                        Write-Log "Created Classic Build Pipeline $($newPipeline.name)"
                        $CreatedPipelinesCount += 1
                    }
                    else {
                        Write-Log "Failed to create Classic Build Pipeline $($definition.name)"
                        $FailedPipelinesCount += 1
                    } 
                    
                    Move-BuildEnvironmentPipelinePermissions -SourceProjectName $SourceProjectName `
                        -SourceOrgName $SourceOrgName -SourceHeaders $SourceHeaders -TargetProjectName `
                        $TargetProjectName -TargetOrgName $TargetOrgName -TargetHeaders $TargetHeaders
                }  
            }
            catch {
                $FailedPipelinesCount += 1
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                Write-Log -Message $_ -LogLevel ERROR
                Write-Log -Message " "
            }   
        }

        Write-Log "Successfully migrated $CreatedPipelinesCount classic pipeline(s) with a hardcoded service connection id input"
        Write-Log "Failed to migrate $FailedPipelinesCount classic pipeline(s) with a hardcoded service connection id input"
    }
}

function New-Pipeline {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [Object]$PipelineDefinition
    )

    $PipelineDefinition.process.phases[0].jobAuthorizationScope = $PipelineDefinition.jobAuthorizationScope

    $definition = @{
        name                      = $PipelineDefinition.name
        type                      = $PipelineDefinition.type
        queue                     = $PipelineDefinition.queue
        process                   = @{
            type   = $PipelineDefinition.process.type  
            phases = $PipelineDefinition.process.phases
            target = $PipelineDefinition.process.target
        }
        repository                = $PipelineDefinition.repository
        project                   = $PipelineDefinition.project
        path                      = $PipelineDefinition.path
        jobAuthorizationScope     = $PipelineDefinition.jobAuthorizationScope
        authoredBy                = $PipelineDefinition.authoredBy
        jobCancelTimeoutInMinutes = $PipelineDefinition.jobCancelTimeoutInMinutes
        jobTimeoutInMinutes       = $PipelineDefinition.jobTimeoutInMinutes
        createdDate               = $PipelineDefinition.createdDate
    }

    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/build/definitions?api-version=7.1"
    $body = $definition | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Method POST -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    return $response
}

function Move-BuildEnvironmentPipelinePermissions {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )

    $sourceProject = Get-ADOProjects -OrgName $SourceOrgName -ProjectName `
        $SourceProjectName -Headers $SourceHeaders 
    $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName `
        $TargetProjectName -Headers $TargetHeaders 

    $targetEnvironments = Get-BuildEnvironments -ProjectName $TargetProjectName `
        -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId `
        $targetProject.Id -Top 1000000
    
    $sourceEnvironments = Get-BuildEnvironments -ProjectName $SourceProjectName `
        -OrgName $SourceOrgName -Headers $SourceHeaders -ProjectId `
        $sourceProject.Id -Top 1000000
    
    foreach ($targetEnvironment in $targetEnvironments) {
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------"
        Write-Log -Message "----- Processing  Environment $($sourceEnvironment.name) -----"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------"

        $sourceEnvironment = $sourceEnvironments | Where-Object { $_.name -eq $targetEnvironment.name }

        if ($NULL -ne $sourceEnvironment) {
            # Get and Update Role Assignments
            $sourceRoleAssignments = Get-BuildEnvironmentRoleAssignments -ProjectName `
                $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -ProjectId `
                $sourceProject.Id -EnvironmentId $sourceEnvironment.Id
            $targetRoleAssignments = $NULL
            Write-Log -Message "--- User permissions --- "
            $targetRoleAssignments = Get-BuildEnvironmentRoleAssignments -ProjectName `
                $targetProjectName -OrgName $targetOrgName -Headers $targetheaders `
                -ProjectId $targetProject.Id -EnvironmentId $targetEnvironment.Id
                
            foreach ($roleAssignment in $sourceRoleAssignments) { 
                $roleName = $roleAssignment.identity.displayName.Replace($SourceProjectName, $TargetProjectName)

                try {
                    Write-Log -Message "Attempting to create role assignment [$($roleName)] in target.. "

                    $query = $targetRoleAssignments | Where-Object { $_.name -eq $roleAssignment.name }

                    if ($query) {
                        Write-Log -Message "Role assignment $($roleAssignment.name) already exists."
                        continue
                    }

                    $identities = Get-IdentitiesByName -OrgName $TargetOrgName -Headers $TargetHeaders -DisplayName $roleName

                    if ($identities.Count -eq 1) {
                        $data = @{
                            "roleName" = $roleAssignment.Role.Name
                            "userId"   = $identities.Value[0].id
                        }
            
                        $scope = $roleAssignment.Role.Scope
                        Write-Log -Message " "
                        Write-Log -Message "Create new Role Assignment $($roleAssignmentIdentityId) / $($roleAssignment.role.name) in target.."
                        Write-Log -Message "Scope: $scope"
                        Write-Log -Message "Source Environment ID: $($sourceEnvironment.Id)"
                        Write-Log -Message "Source Identity Display Name: $($roleAssignment.Identity.displayName)"
                        Write-Log -Message "Source Identity Id: $($roleAssignment.Identity.Id)"
                        Write-Log -Message "Source Role Name: $($roleAssignment.role.name)"
                        Write-Log -Message "Target Identity Id: $($identities.Value[0].id)"
                        Write-Log -Message "Target Role Name: $($roleAssignment.role.name)"
                        Write-Log -Message "Target Environment ID: $($targetEnvironment.Id)"
                        Write-Log -Message "Target Org Name: $TargetOrgName"
                        Write-Log -Message "Target Project ID: $($targetProject.Id)"
                        Write-Log -Message " "

                        Set-BuildEnvironmentRoleAssignment -ProjectName $TargetProjectName `
                            -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId `
                            $targetProject.Id -EnvironmentId $targetEnvironment.Id -ScopeId `
                            $scope -RoleAssignment $data
                    }
                    else {
                        Write-Log -Message "Unable to find role $roleName, please add it manually" -LogLevel WARNING
                    }
            
                }
                catch {
                    Write-Log -Message "FAILED!" -LogLevel ERROR
                    Write-Log -Message $_.Exception -LogLevel ERROR
                    Write-Log -Message $_ -LogLevel ERROR
                    Write-Log -Message " "
                }
            }


    
            # Get and Update pipeline permissions
            Write-Log -Message "--- Pipline permissions --- "

            Write-Log -Message "Get Source Pipline permissions.."
            $sourcePipelinePermissions = Get-BuildEnvironmentPipelinePermissions -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -EnvironmentId $sourceEnvironment.Id
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
                $sourcePipeline = Get-Pipelines -Headers $SourceHeaders -OrgName `
                    $SourceOrgName -ProjectName $SourceProjectName -DefinitionId `
                    $pipelinePermission.Id
                $targetPipeline = ($targetPipelines | Where-Object { $_.Name -ceq $sourcePipeline.Name })
                    
                if ($NULL -ne $targetPipeline) {
                    $object = [PSCustomObject]@{
                        id         = $targetPipeline.Id
                        authorized = $pipelinePermission.Authorized
                    }
                    $newPipelinePermissions += $object
                }
                else {
                    Write-Log -Message "Unable to map Source Pipeline ID [$($pipelinePermission.Id)] to a Target pipeline in order to set a Environment pipeline permission.." -LogLevel ERROR
                }
            }

            try {
                Write-Log -Message "Update Target Pipline permissions.."
                    
                Write-Log -Message " "
                Write-Log -Message "Target Environment Id: $($targetEnvironment.Id)"
                Write-Log -Message "PipelinePermissions: $(ConvertTo-Json -Depth 100 $newPipelinePermissions)"
                    
                Set-BuildEnvironmentPipelinePermissions -ProjectName $TargetProjectName -OrgName $TargetOrgName `
                    -Headers $Targetheaders -EnvironmentId $targetEnvironment.Id -PipelinePermissions $newPipelinePermissions
            }
            catch {
                Write-Log -Message "FAILED to Update Build Environment User Permissions ROle Assignment!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                }
                catch {}
            }
        }
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------"
    }
}

function Get-Pipelines {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/pipelines?api-version=7.2-preview.1"

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results.value
}

function Move-TaskGroups {
    param (
        [Parameter (Mandatory = $TRUE)]
        [array]$SourceTaskGroups,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )

    $targetTaskGroups = Get-TaskGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName `
        -Headers $TargetHeaders

    Write-Log -Message "Migrating $($SourceTaskGroups.count) Task Groups."
    
    foreach ($stg in $SourceTaskGroups) {
        Write-Log -Message "Migrating Task Group: $($stg.name)."
        $query = $targetTaskGroups.value | Where-Object { $_.name -eq $stg.name }

        if ($null -eq $query) {
            try {
                New-TaskGroup -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers `
                    $TargetHeaders -TaskGroup $stg
    
                Write-Log -Message "Migrated Successfully."
            }
            catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                Write-Log -Message $_ -LogLevel ERROR
            }
        }
        else {
            Write-Log -Message "Task Group $($stg.name) already exists."
        }
    }
}

function New-TaskGroup {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        $TaskGroup
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/distributedtask/" `
        + "taskgroups?api-version=7.1"
    $body = ConvertTo-Json -Depth 32 $TaskGroup

    $result = Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType `
        "application/json" -Headers $TargetHeaders

    return $result
}

function Get-TaskGroups {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/distributedtask/taskgroups" `
        + "?api-version=7.1"

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results
}

function Get-TargetTaskId {
    param (
        [Parameter (Mandatory = $TRUE)]
        $SourceTaskGroups,

        [Parameter (Mandatory = $TRUE)]
        $TargetTaskGroups,

        [Parameter (Mandatory = $TRUE)]
        [string]$SourceTaskGroupId
    )
    
    $stg = $SourceTaskGroups | Where-Object { $_.id -eq $SourceTaskGroupId }
    $result = $SourceTaskGroupId

    if ($stg) {
        $ttg = $TargetTaskGroups | Where-Object { $_.name -eq $stg.name }

        if ($ttg) {
            $result = $ttg.id
        }
    }

    return $result
}