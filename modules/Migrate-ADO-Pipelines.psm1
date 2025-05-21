function Get-Pipelines {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [String]$RepoId = $NULL
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions?api-version=7.0"
        if ($RepoId) {
            $url = "https://dev.azure.com//$OrgName/$ProjectName/_apis/build/definitions?repositoryId=$RepoId&repositoryType=TfsGit";
        }
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results.value
    }
}

function Migrate-ClassicPipelines {
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
        $sourcePipelinesUrl = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/pipelines?api-version=7.2-preview.1"
        $sourcePipelines = Invoke-RestMethod -Uri $sourcePipelinesUrl -Headers $SourceHeaders -Method Get
        $targetPipelinesUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/pipelines?api-version=7.2-preview.1"
        $targetPipelines = Get-Pipelines -Headers $TargetHeaders -ProjectName $targetProjectName -OrgName $TargetOrgName
        $targetPipelineNames = $targetPipelines | Select-Object -ExpandProperty name

        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $sourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $TargetHeaders
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders
        $targetAgentPoolsUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/distributedtask/queues?api-version=7.1"
        $targetAgentPools = Invoke-RestMethod -Method GET -uri $targetAgentPoolsUrl -Headers $TargetHeaders

        $pipelinesToMigrate = $sourcePipelines.value | Where-Object { $targetPipelineNames -notcontains $_.name }
        $CreatedPipelinesCount = 0 
        $FailedPipelinesCount = 0
        foreach ($pipeline in $pipelinesToMigrate) {
            $CreatePipeline = $false

            $pipelineId = $pipeline.id
            $definitionUrl = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/build/definitions/$($pipelineId)?api-version=7.2-preview"
           
            $definition = Invoke-RestMethod -Uri $definitionUrl -Headers $SourceHeaders -Method Get
            
            foreach ($phase in $definition.process.phases) {
                foreach ($step in $phase.steps) {
                    #If the service connection ID is located, the we have to swap the value for the appropriate target service connection
                    $ServiceConnectionIdforRunningFortifyScan = $step.inputs.cloudScanfortifyServerName
                    $ExternalEndpointsServiceConnectionIds = $step.inputs.externalEndpoints -split ","
                    $AzureServiceConnectionId = $step.inputs.azureSubscription
                    if($ServiceConnectionIdforRunningFortifyScan -ne $null) {
                        
                        $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                        $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                        $step.inputs.cloudScanfortifyServerName = $targetServiceConnectionId
                        if($MigrateOnlyProblematicPipelines){
                            $CreatePipeline = $true
                        }
                    }
                    if($ExternalEndpointsServiceConnectionIds -ne $null) {
                        $endpointsString = ""
                        forEach($endpoint in $ExternalEndpointsServiceConnectionIds) {
                            if($endpoint -ne "") {
                                $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                                $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                                $endpointsString += ",$targetServiceConnectionId"                                
                            }                            
                        }
                        $step.inputs.externalEndpoints = $endpointsString
                        if($MigrateOnlyProblematicPipelines){
                            $CreatePipeline = $true
                        }
                    }
                    if($AzureServiceConnectionId  -ne $null) {
                        $serviceConnectionName = $sourceEndpoints | Where-Object { $_.id -eq $ServiceConnectionIdforRunningFortifyScan } | Select-Object -ExpandProperty name
                        $targetServiceConnectionId = $targetEndpoints | Where-Object { $_.name -eq $serviceConnectionName } | Select-Object -ExpandProperty id
                        $step.inputs.azureSubscription = $targetServiceConnectionId
                        if($MigrateOnlyProblematicPipelines){
                            $CreatePipeline = $true
                        }
                    }               
                }
            }
            if(!$MigrateOnlyProblematicPipelines -OR $CreatePipeline -eq $true) {
                Write-Log "Creating Pipeline $($definition.name) using PowerShell due to hardcoded a harcoded service connection id inputs"
                $repoName = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders -repoId $($definition.repository.id) | Select-Object -ExpandProperty name
                $targetRepos = Invoke-RestMethod -Uri "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/git/repositories?api-version=7.1-preview.1" -Headers $TargetHeaders
                $targetRepo = $targetRepos | Where-Object {$_.name -eq $repoName }
                $targetAgentPool = $targetAgentPools.value | Where-Object { $_.name -eq $definition.queue.name}
                
                $definition.repository.id = $targetRepo.id
                $definition.repository.url = "https://dev.azure.com/$targetOrgName/$targetProjectName/_git/$repoName"
                $definition.project.id = $targetProject.id
                $definition.queue.id = $targetAgentPool.id
                $definition.queue.url =  "https://dev.azure.com/$targetOrgName/_apis/build/Queues/$($targetAgentPool.id)"
                $definition.queue.pool.id =  $targetAgentPool.pool.id
                $definition.repository.id = $targetRepo.id
                $definition.repository.url = "https://dev.azure.com/$targetOrgName/$targetProjectName/_git/$repoName"
                $definition.project.id = $targetProject.id
                $definition.queue.id = $targetAgentPool.id
                $definition.queue.url =  "https://dev.azure.com/$targetOrgName/_apis/build/Queues/$($targetAgentPool.id)"
                $definition.queue.pool.id =  $targetAgentPool.pool.id

                forEach($phase in $definition.process.phases){
                    if($phase.target.queue -ne $null){
                        $phase.target.queue.id = $targetAgentPool.id
                        $phase.target.queue.url = "https://dev.azure.com/$targetOrgName/_apis/build/Queues/$($targetAgentPool.id)"
                    }
                }

                if($definition.queue.pool.isHosted -ne $null) {
                    $definition.queue.pool.isHosted =  $targetAgentPool.pool.isHosted
                }
                
                $newPipeline = New-Pipeline -PipelineDefinition $definition -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
                if($newPipeline -ne $null){
                    Write-Log "Created Classic Build Pipeline $($newPipeline.name)"
                    $CreatedPipelinesCount += 1
                } else {
                    Write-Log "Failed to create Classic Build Pipeline $($definition.name)"
                    $FailedPipelinesCount += 1
                }
                
            }            
        }

        Write-Log "Successfully migrated $CreatedPipelinesCount classic pipeline(s) with hardcoded service connection id inputs"
        Write-Log "Failed to migrate $FailedPipelinesCount classic pipeline(s) with hardcoded service connection id inputs"
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
    $definition = @{
        name = $PipelineDefinition.name
        type = $PipelineDefinition.type
        queue = $PipelineDefinition.queue
        process = @{
            type = $PipelineDefinition.process.type  
            phases = $PipelineDefinition.process.phases
            target = $PipelineDefinition.process.target
        }
        repository = $PipelineDefinition.repository
        project = $PipelineDefinition.project
    }


    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions?api-version=7.1"
    $body = $definition | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Method POST -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    return $response
}
