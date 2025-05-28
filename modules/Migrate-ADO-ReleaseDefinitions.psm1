
function Start-ADOReleaseDefinitionsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Release Definitions from source project $SourceOrgName/$SourceProjectName")
    ) {
        $ErrorActionPreference = "Continue"
        Write-Log -Message ' '
        Write-Log -Message '---------------------------------'
        Write-Log -Message '-- Migrate Release Definitions --'
        Write-Log -Message '---------------------------------'
        Write-Log -Message ' '

        $sourceReleases = Get-ReleaseDefinitions -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
        $targetReleases = Get-ReleaseDefinitions -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
        $sourceProject = Get-ADOProjects -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
        $targetProject = Get-ADOProjects -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders

        $sourceAgentPools = Get-BuildQueues -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
        $targetAgentPools = Get-BuildQueues -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
 
        $targetReleasePipelineNames = $targetReleases.value | Select-Object -ExpandProperty name 
        $releasesToMigrate = $sourceReleases.value | Where-Object { $targetReleasePipelineNames -notcontains $_.name }

        $sourceVariableGroups = Get-VariableGroups -projectName $SourceProjectName -orgName $SourceOrgName -headers $SourceHeaders
        $targetVariableGroups = Get-VariableGroups -projectName $TargetProjectName -orgName $TargetOrgName -headers $TargetHeaders

        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $SourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $TargetHeaders

        Write-Log "Attempting to migrate $($releasesToMigrate.count) releases"
        $CreatedPipelinesCount = 0 
        $FailedPipelinesCount = 0

        Migrate-DeploymentGroups -SourceProjectName $SourceProjectName -SourceOrgName $SourceOrgName -SourceHeaders $SourceHeaders -TargetProjectName $TargetProjectName -TargetOrgName $TargetOrgName -TargetHeaders $TargetHeaders -TargetProjectId $($targetProject.id)

        ForEach ($release in $releasesToMigrate) {
            Write-Log "Migrating Release Pipeline: $($release.name)"
            $releaseDetailUrl = "https://vsrm.dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/release/definitions/$($release.id)?api-version=7.1-preview.4"
            $releaseDetail = Invoke-RestMethod -Method GET -Uri $releaseDetailUrl -Headers $SourceHeaders
            forEach ($environment in $releaseDetail.environments) {
                $environment.currentRelease.url = $environment.currentRelease.url.Replace($SourceOrgName, $TargetOrgName).Replace($sourceProject.id, $targetProject.id)
                $environment.badgeUrl = ""
                forEach ($phase in $environment.deployPhases) {
                    #TODO: Need to locate the target deployment group id by name from the target deployment groups, NOT build agent pools
                    $agentPoolName = $sourceAgentPools | Where-Object { $_.id -eq $phase.deploymentInput.queueId } | Select-Object -ExpandProperty name
                    if ($null -eq $agentPoolName) {
                        Write-Log "Could not locate the desired agent pool for this release pipeline in the source project. Using 'Azure Pipelines' instead."
                        $agentPoolName = "Azure Pipelines"
                    }
                    $targetQueue = $targetAgentPools | Where-Object { $_.name -eq $agentPoolName }
                    $phase.deploymentInput.queueId = $targetQueue.id
                    forEach ($workflowTask in $phase.workflowTasks) {
                        if ($workflowTask.name -like "Azure Logic Apps Standard Release*" -OR 
                            $workflowTask.name -like "Restart App Service" -OR 
                            $workflowTask.name -like "Azure App Service Deploy*" -OR 
                            $workflowTask.name -like "VsTest - testAssemblies") {
                            $targetServiceConnectionId = Get-TargetServiceConnectionId -SourceEndpoints $sourceEndpoints -TargetEndpoints $targetEndpoints -SourceServiceConnectionId $($workflowTask.inputs.connectedServiceName)
                            $workflowTask.inputs.connectedServiceName = $targetServiceConnectionId
                        
                        }
                    }

                }
                if ($null -ne $environment.variableGroups -AND $environment.variableGroups.Count -gt 0) {
                    $variableGroups = @()
                    forEach ($variableGroupId in $environment.variableGroups) {
                        $variableGroupName = $sourceVariableGroups | Where-Object { $_.id -eq $variableGroupId } | Select-Object -ExpandProperty name
                        $targetVariableGroupId = $targetVariableGroups | Where-Object { $_.name -eq $variableGroupName } | Select-Object -ExpandProperty id
                        $variableGroups += $targetVariableGroupId
                    }
                    $environment.variableGroups = $variableGroups
                }
            }
            forEach ($artifact in $releaseDetail.artifacts) {
                $artifact.sourceId = $artifact.sourceId.Replace($sourceProject.id, $targetProject.id).Replace($sourceProject.id, $targetProject.id)
                if ($null -ne $artifact.definitionReference.artifactSourceDefinitionUrl) {
                    $artifact.definitionReference.artifactSourceDefinitionUrl.id = $artifact.definitionReference.artifactSourceDefinitionUrl.id.Replace($SourceOrgName, $TargetOrgName)
                }                
                $artifact.definitionReference.project.id = $TargetProject.id
                $artifact.definitionReference.project.name = $TargetProjectName
            }
            $releaseDetail.id = 0
            $releaseDetail.url = ""
            $releaseDetail._links = ""
            
            try {
                $newPipeline = Create-ReleaseDefinition -ProjectName $targetProjectName -OrgName $targetOrgName -Headers $TargetHeaders -DefinitionDetail $releaseDetail
                if ($null -ne $newPipeline) {
                    Write-Log "Created Release Pipeline $($newPipeline.name)"
                    $CreatedPipelinesCount += 1
                }
                else {
                    Write-Log "Failed to create Release Pipeline $($definition.name)"
                    $FailedPipelinesCount += 1
                }  
            }
            catch {
                Write-Log "Catch!"
                Write-Log "Failed to create Release Pipeline $($definition.name)"
                $FailedPipelinesCount += 1
                Write-Log "$($_)"
            }
        }
        Write-Log "Successfully migrated $CreatedPipelinesCount release pipeline(s)"
        Write-Log "Failed to migrate $FailedPipelinesCount release pipeline(s)"
    }
}

function Get-ReleaseDefinitions {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    $url = "https://vsrm.dev.azure.com/$OrgName/$ProjectName/_apis/release/definitions?api-version=7.1"
    $response = Invoke-RestMethod -Method GET -uri $url -Headers $Headers
    return $response
}

function Get-ReleaseDefinition {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$DefinitionId
    )
    $url = "https://vsrm.dev.azure.com/$OrgName/$ProjectName/_apis/release/definitions/$($release.id)?api-version=7.1-preview.4"
    $response = Invoke-RestMethod -Method GET -uri $url -Headers $Headers
    return $response
}

function Create-ReleaseDefinition {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [Object]$DefinitionDetail
    )
    $url = "https://vsrm.dev.azure.com/$OrgName/$ProjectName/_apis/release/definitions?api-version=7.1"
    
    $body = $DefinitionDetail | ConvertTo-Json -Depth 100
    $response = Invoke-WebRequest -Uri $url -Method POST -Header $Headers -Body $body -ContentType "application/json"
    return $response
}

function Get-TargetServiceConnectionId {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String[]]$SourceEndpoints,

        [Parameter (Mandatory = $TRUE)]
        [String[]]$TargetEndpoints,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceServiceConnectionId
    )
    $serviceConnectionName = $SourceEndpoints | Where-Object { $_.id -eq $SourceServiceConnectionId } | Select-Object -ExpandProperty name
    $targetServiceConnectionId = $TargetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
    return $targetServiceConnectionId
}

function Migrate-DeploymentGroups {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $TRUE)]
        [string]$TargetProjectId
    )
    $sourceDeploymentGroupsUrl = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/distributedtask/deploymentgroups?api-version=7.1"
    $sourceDeploymentGroups = Invoke-RestMethod -Method GET -uri $sourceDeploymentGroupsUrl -Headers $SourceHeaders 

    $targetDeploymentGroupsUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/distributedtask/deploymentgroups?api-version=7.1"
     
    # $targetDeploymentGroups = Invoke-RestMethod -Method GET -uri $targetDeploymentGroupsUrl -Headers $TargetHeaders 

    $targetPoolsUrl = "https://dev.azure.com/$TargetOrgName/_apis/distributedtask/pools?api-version=7.1"
    $targetAgentPools = Invoke-RestMethod -Method GET -uri $targetPoolsUrl -Headers $TargetHeaders

    forEach ($deploymentGroup in $sourceDeploymentGroups.value) {
        try {
            $poolId = $deploymentGroup.pool.id
            $poolUrl = "https://dev.azure.com/$sourceOrgName/_apis/distributedtask/pools/$($poolId)?api-version=7.1"
            $pool = Invoke-RestMethod -Method GET -uri $poolUrl -Headers $sourceHeaders
            $targetPool = $targetAgentPools.value | Where-Object { $_.name -eq $pool.name }
            if ($targetPool.Count -eq 0) {
                $newPool = New-Pool -TargetOrgName $TargetOrgName -TargetHeaders $TargetHeaders -Pool $pool -TargetProjectName $TargetProjectName

                $deploymentGroup.pool.id = $newPool.id
            }
            else {
                $deploymentGroup.pool.id = $targetPool.id
            }
            
            Write-Log "Attempting to migrate deployment group $($deploymentGroup.name)"
            $url = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/distributedtask/deploymentgroups?api-version=7.1"
            $deploymentGroup.project.id = $targetProjectId
            $deploymentGroup.project.name = $TargetProjectName
            $newDeploymentGroup = Invoke-RestMethod -Method POST -Uri $url -Headers $TargetHeaders `
                -ContentType "application/json"
            if ($null -ne $newDeploymentGroup) {
                Write-Log "Deployment group $($deploymentGroup.name) migrated successfully."
            }
            else {
                Write-Log "Deployment group $($deploymentGroup.name) failed to migrate."
            }
        }
        catch {
            Write-Log "Catch!"
            Write-Log "Failed to migrate deployment group $($deploymentGroup.name)"
            $FailedPipelinesCount += 1
            Write-Log "$($_)"
        }
    }
}

function New-Pool {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter(Mandatory = $TRUE)]
        $Pool
    )
    $url = "https://dev.azure.com/$TargetOrgName/_apis/distributedtask/pools?api-version=7.2-preview.1"
    
    $body = $Pool | ConvertTo-Json -Depth 32

    $newPool = Invoke-RestMethod -Method Post -Uri $url -Headers $TargetHeaders `
        -Body $body -ContentType "application/json"

    return $newPool
}


     

