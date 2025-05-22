
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

        Write-Log "Attempting to migrate $($releasesToMigrate.count) releases"
        $CreatedPipelinesCount = 0 
        $FailedPipelinesCount = 0

        ForEach($release in $releasesToMigrate) {
            Write-Log "Migrating Release Pipeline: $($release.name)"
            $releaseDetailUrl = "https://vsrm.dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/release/definitions/$($release.id)?api-version=7.1-preview.4"
            $releaseDetail = Invoke-RestMethod -Method GET -Uri $releaseDetailUrl -Headers $SourceHeaders
            forEach($environment in $releaseDetail.environments){
                $environment.currentRelease.url = $environment.currentRelease.url.Replace($SourceOrgName,$TargetOrgName).Replace($sourceProject.id,$targetProject.id)
                $environment.badgeUrl = $environment.badgeUrl.Replace($SourceOrgName,$TargetOrgName).Replace($sourceProject.id,$targetProject.id)
                forEach($phase in $environment.deployPhases) {
                    $agentPoolName = $sourceAgentPools | Where-Object {$_.id -eq $phase.deploymentInput.queueId}
                    if($agentPoolName -eq $null) {
                        Write-Log "Could not locate the desired agent pool for this release pipeline in the source project. Using 'Azure Pipelines' instead."
                        $agentPoolName = "Azure Pipelines"
                    }
                    $targetQueueId = $targetAgentPools | Where-Object {$_.name -eq $agentPoolName}
                    $phase.deploymentInput.queueId = $targetQueueId
                }
            }
            forEach($artifact in $releaseDetail.artifacts){
                $artifact.sourceId = $artifact.sourceId.Replace($sourceProject.id,$targetProject.id).Replace($sourceProject.id,$targetProject.id)
                $artifact.definitionReference.artifactSourceDefinitionUrl.id = $artifact.definitionReference.artifactSourceDefinitionUrl.id.Replace($SourceOrgName,$TargetOrgName)
                $artifact.definitionReference.project.id = $TargetProject.id
                $artifact.definitionReference.project.name = $TargetProjectName
            }
            $releaseDetail.url = $releaseDetail.url.Replace($SourceOrgName,$TargetOrgName).Replace($sourceProject.id,$targetProject.id)
            $releaseDetail._links.self.href = $releaseDetail._links.self.href.Replace($SourceOrgName,$TargetOrgName).Replace($sourceProject.id,$targetProject.id)
            $releaseDetail._links.web.href = $releaseDetail._links.web.href.Replace($SourceOrgName,$TargetOrgName).Replace($sourceProject.id,$targetProject.id)
           
            try{
                $newPipeline = Create-ReleaseDefinition -ProjectName $targetProjectName -OrgName $targetOrgName -Headers $TargetHEaders -Definition $release -DefinitionDetail $releaseDetail
                if($newPipeline -ne $null){
                    Write-Log "Created Release Pipeline $($newPipeline.name)"
                    $CreatedPipelinesCount += 1
                } else {
                    Write-Log "Failed to create Release Pipeline $($definition.name)"
                    $FailedPipelinesCount += 1
                }  
            } catch {
                Write-Log "Failed to create Release Pipeline $($definition.name)"
                $FailedPipelinesCount += 1
                Write-Error "$($_.Exception)"
            }
        }
        Write-Log "Successfully migrated $CreatedPipelinesCount release pipeline(s)"
        Write-Log "Failed to migrate $FailedPipelinesCount release pipeline(s)"
    }
}

function Get-ReleaseDefinitions{
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
        [Object]$Definition,

        [Parameter (Mandatory = $TRUE)]
        [Object]$DefinitionDetail
    )
    $url = "https://vsrm.dev.azure.com/$OrgName/$ProjectName/_apis/release/definitions?api-version=7.1"
    $body = $DefinitionDetail | ConvertTo-Json -Depth 12

    $response = Invoke-WebRequest -Uri $url -Method POST -Header $Headers -Body $body -ContentType "application/json"
    return $response
}

