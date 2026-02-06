Using Module "..\modules\Migrate-ADO-Common.psm1"
Using module "..\modules\Migrate-ADO-VariableGroups.psm1"
Using module "..\modules\Migrate-ADO-Pipelines.psm1"
Using module "..\modules\Migrate-ADO-ServiceConnections.psm1"

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
 
        $targetReleasePipelineNames = $targetReleases.value | Select-Object -ExpandProperty name 
        $releasesToMigrate = $sourceReleases.value | Where-Object { $targetReleasePipelineNames -notcontains $_.name }

        $sourceVariableGroups = Get-VariableGroups -projectName $SourceProjectName -orgName $SourceOrgName -headers $SourceHeaders
        $targetVariableGroups = Get-VariableGroups -projectName $TargetProjectName -orgName $TargetOrgName -headers $TargetHeaders

        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $SourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $TargetHeaders

        Write-Log "Attempting to migrate $($releasesToMigrate.count) releases"
        $CreatedPipelinesCount = 0 
        $FailedPipelinesCount = 0

        Move-DeploymentPools -SourceProjectName $SourceProjectName -SourceOrgName $SourceOrgName `
            -SourceHeaders $SourceHeaders -TargetProjectName $TargetProjectName -TargetOrgName $TargetOrgName `
            -TargetHeaders $TargetHeaders
        Move-AgentPools -SourceOrgName $SourceOrgName -SourceProjectName $SourceProjectName `
            -SourceHeaders $SourceHeaders -TargetOrgName $TargetOrgName -TargetProjectName $TargetProjectName `
            -TargetHeaders $TargetHeaders
        Move-DeploymentGroups -SourceProjectName $SourceProjectName -SourceOrgName $SourceOrgName `
            -SourceHeaders $SourceHeaders -TargetProjectName $TargetProjectName -TargetOrgName $TargetOrgName `
            -TargetHeaders $TargetHeaders

        $sourceTaskGroups = Get-TaskGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName `
            -Headers $SourceHeaders
        $targetTaskGroups = Get-TaskGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName `
            -Headers $TargetHeaders

        ForEach ($release in $releasesToMigrate) {
            Write-Log "Migrating Release Pipeline: $($release.name)"
            $releaseDetail = Get-ReleaseDetail -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders

            forEach ($environment in $releaseDetail.environments) {
                $environment.currentRelease.url = $environment.currentRelease.url.Replace($SourceOrgName, $TargetOrgName).Replace($sourceProject.id, $targetProject.id)
                $environment.badgeUrl = ""

                forEach ($phase in $environment.deployPhases) {
                    forEach ($workflowTask in $phase.workflowTasks) {
                        if (($workflowTask.name -like "Azure Logic Apps Standard Release*" -OR 
                                $workflowTask.name -like "Restart App Service" -OR 
                                $workflowTask.name -like "Azure App Service Deploy*" -OR 
                                $workflowTask.name -like "VsTest - testAssemblies") -AND
                            $workflowTask.inputs.connectedServiceName) {
                            $targetServiceConnectionId = Get-TargetServiceConnectionId -SourceEndpoints $sourceEndpoints `
                                -TargetEndpoints $targetEndpoints -SourceServiceConnectionId $($workflowTask.inputs.connectedServiceName)
                            $workflowTask.inputs.connectedServiceName = $targetServiceConnectionId
                        }

                        $workflowTask.taskId = Get-TargetTaskId -SourceTaskGroups $sourceTaskGroups.value -TargetTaskGroups `
                            $targetTaskGroups.value -SourceTaskGroupId $workflowTask.taskId
                    }

                    # Remvoe disabled workflow tasks
                    $phase.workflowTasks = @($phase.workflowTasks | Where-Object { $_.enabled -eq $true })

                    # Remove deploymentInput property from request body
                    $phase.PSObject.Properties.Remove("deploymentInput")
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

            # Set variable groups to target Ids
            if ($releaseDetail.variableGroups) {
                $vgs = @()
                foreach ($vgId in $releaseDetail.variableGroups) {
                    $vg = $sourceVariableGroups | Where-Object { $_.id -eq $vgId }
                    if ($vg) {
                        $tvg = $targetVariableGroups | Where-Object { $_.name -eq $vg.name } 
                        if ($tvg) {
                            $vgs += $tvg.id
                        }
                    }
                }
                $releaseDetail.variableGroups = $vgs
            }
            
            try {
                $newPipeline = New-ReleaseDefinition -ProjectName $targetProjectName -OrgName $targetOrgName -Headers $TargetHeaders -DefinitionDetail $releaseDetail
                if ($null -ne $newPipeline) {
                    Write-Log "Created Release Pipeline $($release.name)"
                    $CreatedPipelinesCount += 1
                }
                else {
                    Write-Log "Failed to create Release Pipeline $($release.name)"
                    $FailedPipelinesCount += 1
                }  
            }
            catch {
                Write-Log "Catch!"
                Write-Log "Failed to create Release Pipeline $($release.name)"
                $FailedPipelinesCount += 1
                Write-Log "$($_)"
            }
        }
        Write-Log "Successfully migrated $CreatedPipelinesCount release pipeline(s)"
        Write-Log "Failed to migrate $FailedPipelinesCount release pipeline(s)"
    }
}

function Get-ReleaseDetail {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://vsrm.dev.azure.com/$($OrgName)/$($ProjectName)/_apis/release/definitions" `
        + "/$($release.id)?api-version=7.1-preview.4"

    $result = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $result
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

function New-ReleaseDefinition {
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
    $url = "https://vsrm.dev.azure.com/$($OrgName)/$($ProjectName)/_apis/release/definitions?api-version=7.1"
    
    $body = $DefinitionDetail | ConvertTo-Json -Depth 32
    $result = Invoke-WebRequest -Uri $url -Method POST -Header $Headers -Body $body -ContentType "application/json"

    return $result
}

function Get-TargetServiceConnectionId {
    param(
        [Parameter (Mandatory = $TRUE)]
        $SourceEndpoints,

        [Parameter (Mandatory = $TRUE)]
        $TargetEndpoints,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceServiceConnectionId
    )
    $serviceConnectionName = $SourceEndpoints | Where-Object { $_.id -eq $SourceServiceConnectionId } | Select-Object -ExpandProperty name
    $targetServiceConnectionId = $TargetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
    return $targetServiceConnectionId
}

function Move-DeploymentGroups {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,

        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )
    $sourceDeploymentGroups = Get-DeploymentGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders
    $targetDeploymentGroups = Get-DeploymentGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders
    $targetDeploymentPools = Get-Pools -OrgName $TargetOrgName -Headers $TargetHeaders -PoolType "deployment"

    forEach ($sdg in $sourceDeploymentGroups.value) {
        try {
            $query = $targetDeploymentGroups.value | Where-Object { $_.name -eq $sdg.name }

            if ($query) {
                Write-Log "Deployment group $($sdg.name) already exist."
                continue
            }

            Write-Log "Attempting to migrate deployment group $($sdg.name)"

            $deploymentPool = $targetDeploymentPools.value | Where-Object { $_.name -eq $sdg.pool.name } | Select-Object -First 1

            if ($deploymentPool) {
                $deploymentGroup = @{
                    "description" = $sdg.description
                    "name"        = $sdg.name
                    "poolId"      = $deploymentPool.id
                }
            
                $newDeploymentGroup = New-DeploymentGroup -OrgName $TargetOrgName -ProjectName $TargetProjectName `
                    -Headers $TargetHeaders -DeploymentGroup $deploymentGroup

                if ($null -ne $newDeploymentGroup) {

                    Write-Log "Deployment group $($deploymentGroup.name) migrated successfully."
                }
                else {
                    Write-Log "Deployment group $($deploymentGroup.name) failed to migrate."
                }
            }
            else {
                Write-Log "Unable to find Agent Pool $($sdg.pool.name)"
            }
            

        }
        catch {
            Write-Log "Catch!"
            Write-Log "Failed to migrate deployment group $($deploymentGroup.name)"
            Write-Log "$($_)"
        }
    }
}

function Move-AgentPools {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,
         
        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )
    
    $sourceAgentPools = Get-Pools -OrgName $SourceOrgName -Headers $SourceHeaders
    $targetAgentPools = Get-Pools -OrgName $TargetOrgName -Headers $TargetHeaders

    foreach ($sap in $sourceAgentPools.value) {
        $query = $targetAgentPools.value | Where-Object { $_.name -eq $sap.name }

        if ($query.count -eq 0) {
            try {
                $newAgentPool = New-Pool -OrgName $TargetOrgName -Headers $TargetHeaders -Pool $sap

                Move-Agents -SourceOrgName $SourceOrgName -SourceHeaders $SourceHeaders `
                    -TargetOrgName $TargetOrgName -TargetHeaders $TargetHeaders -SourcePoolId $sap.id -TargetPoolId $newAgentPool.id

                Write-Log "Created Agent Pool $($newAgentPool.name)"
            }
            catch {
                Write-Log "Catch!"
                Write-Log "Failed to add Pool $($sap.name)"
                Write-Log "$($_)"
            }
        }
    }
}

function Move-Agents {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 
         
        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter(Mandatory = $TRUE)]
        [String]
        $SourcePoolId,

        [Parameter(Mandatory = $TRUE)]
        [String]
        $TargetPoolId
    )
    
    $agents = Get-Agents -OrgName $SourceOrgName -Headers $SourceHeaders -PoolId $SourcePoolId

    foreach ($a in $agents.value) {
        try {
            New-Agent -OrgName $TargetOrgName -Headers $TargetHeaders -PoolId $TargetPoolId -Agent $a

            Write-Log "Created Agent $($a.name)"
        }
        catch {
            Write-Log "Catch!"
            Write-Log "Failed to add Pool $($a.name)"
            Write-Log "$($_)"
        }
    }
}

function New-Agent {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $TRUE)]
        [String]
        $PoolId,

        [Parameter(Mandatory = $TRUE)]
        [Object]
        $Agent
    )
    
    $url = "https://dev.azure.com/$($OrgName)/_apis/distributedtask/pools/$($PoolId)/agents?api-version=7.1"

    $body = $Agent | ConvertTo-Json -Depth 32

    $result = Invoke-RestMethod -Method Post -Uri $url -Body $body `
        -ContentType "application/json" -Headers $Headers

    return $result
}

function Get-Agents {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $TRUE)]
        [String]
        $PoolId
    )
    
    $url = "https://dev.azure.com/$($OrgName)/_apis/distributedtask/pools/$($PoolId)/agents?api-version=7.1"

    $resuls = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $resuls
}

function Move-DeploymentPools {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,
         
        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )
    
    $sourceDeploymentPools = Get-Pools -OrgName $SourceOrgName -Headers $SourceHeaders -PoolType "deployment"
    $targetDeploymentPools = Get-Pools -OrgName $TargetOrgName -Headers $TargetHeaders -PoolType "deployment"

    foreach ($sdp in $sourceDeploymentPools.value) {
        $query = $targetDeploymentPools.value | Where-Object { $_.name -eq $sdp.name }

        if ($query.count -eq 0) {
            try {
                $newDeploymentPool = New-Pool -OrgName $TargetOrgName -Headers $TargetHeaders -Pool $sdp

                Write-Log "Created Deployment Pool $($newDeploymentPool.name)"
            }
            catch {
                Write-Log "Catch!"
                Write-Log "Failed to add Pool $($sdp.name)"
                Write-Log "$($_)"
            }
        }
    }
}

function New-Pool {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $TRUE)]
        $Pool
    )
    $url = "https://dev.azure.com/$OrgName/_apis/distributedtask/pools?api-version=7.2-preview.1"
    
    $body = $Pool | ConvertTo-Json -Depth 32

    $result = Invoke-RestMethod -Method Post -Uri $url -Headers $Headers `
        -Body $body -ContentType "application/json"

    return $result
}

function Get-Pools {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [String]$PoolType
    )
    
    $url = "https://dev.azure.com/$OrgName/_apis/distributedtask/pools?api-version=7.2-preview.1"

    if ($PoolType) {
        $url = $url + "&poolType=$PoolType"
    }

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results
}

function Remove-AllPools {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )

    $agentPools = Get-Pools -OrgName $OrgName -Headers $Headers

    foreach ($ap in $agentPools.value) {
        try {
            if ($false -eq $ap.owner.displayName.StartsWith("Microsoft")) {

                Remove-Pool -OrgName $OrgName -PoolId $ap.id -Headers $Headers
    
                Write-Log "Pool $($ap.name) removed."
            }
        }
        catch {
            Write-Log "Catch!"
            Write-Log "Failed to remove Pool $($ap.name)"
            Write-Log "$($_)"
        }
    }
}

function Remove-Pool {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PoolId,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://dev.azure.com/$OrgName/_apis/distributedtask/pools/$($PoolId)?api-version=7.2-preview.1"

    $result = Invoke-RestMethod -Method Delete -Uri $url -Headers $Headers

    return $result
}

function Remove-AllReleaseDefinitions {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://vsrm.dev.azure.com/$($OrgName)/$($ProjectName)/_apis/release/definitions?api-version=7.2-preview.4"

    $releaseDefinitions = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    foreach ($rd in $releaseDefinitions.value) {
        try {
            Remove-ReleaseDefinition -OrgName $OrgName -ProjectName $ProjectName -DefinitionId $rd.id -Headers $Headers

            Write-Log "Release definition $($rd.name) removed."
        }
        catch {
            Write-Log "Catch!"
            Write-Log "Failed to remove release definition $($rd.name)"
            Write-Log "$($_)"
        }
    }
}

function Remove-ReleaseDefinition {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$DefinitionId,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://vsrm.dev.azure.com/$($OrgName)/$($ProjectName)/_apis/release/definitions" `
        + "/$($DefinitionId)?api-version=7.2-preview.4"

    $result = Invoke-RestMethod -Method Delete -Uri $url -Headers $Headers

    return $result;
}
function Get-DeploymentGroups {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/distributedtask/deploymentgroups?api-version=7.2-preview.1"

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results;
}

function New-DeploymentGroup {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        $DeploymentGroup,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/distributedtask/deploymentgroups?api-version=7.2-preview.1"

    $body = $DeploymentGroup | ConvertTo-Json -Depth 32

    $results = Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $url -Headers $Headers -Body $body

    return $results;
}


     

