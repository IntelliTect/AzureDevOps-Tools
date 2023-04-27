
function Start-ADOServiceHooksMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $FALSE)] [string]$SecretsMapPath = ""
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Service Hooks from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '---------------------------'
        Write-Log -Message '-- Migrate Service Hooks --'
        Write-Log -Message '---------------------------'
        Write-Log -Message ' '

        $sourceProjectOrg = Get-ADOProjects -OrgName $SourceOrgName -ProjectName $sourceProjectName -Headers $sourceHeaders
        $targetProjectOrg = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $targetProjectName -Headers $targetHeaders

        $SourceTeams = Get-ADOProjectTeams -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName
        $TargetTeams = Get-ADOProjectTeams -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName

        $SourcePipelines = Get-Pipelines -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName
        $TargetPipelines = Get-Pipelines -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName
        

        $targetRepos = Get-Repos -projectName $targetProject.name -headers $targetHeaders -org $TargetOrgName
        
        $maskedValue = "********"
        
        if ($SecretsMapPath -ne "") {
            $secretsMap = ((Get-Content -Raw -Path $SecretsMapPath) | ConvertFrom-Json) | ConvertTo-HashTable
            Write-Log -Message "Loaded secrets map from $SecretsMapPath"    
        }
        else {
            $secretsMap = @{
                serviceHooks = @{
                    webHooks = @{}
                    jenkins  = @{}
                }
            }
            Write-Log -Message "Loaded default secrets map"
        }
        
        $hooks = Get-ServiceHooks -projectId $sourceProjectOrg.id -org $SourceOrgName -headers $sourceHeaders
        
        Write-Log -Message "Located $($hooks.Count) in source."
        
        $hooks | ConvertTo-Json -Depth 10 | Out-File -FilePath "hooks.json"
        
        foreach ($hook in $hooks) {


            # THIS IS A TEMP TESTING BLOCK, REMOVE WHEN DONE TESTING
            if($hook.id -ne "d713f8d6-d8e4-443a-8843-aa01184fda4d") {
                continue
            }



            Write-Log -Message "Attempting to create [$($hook.id)] in target.. "
            try {
                if ($null -ne $hook.publisherInputs) {
                    $hook.publisherInputs.projectId = $targetProjectOrg.id
                    
                    if($null -ne $hook.publisherInputs.repository) {
                        $sourceRepo = Get-Repo -headers $sourceHeaders -org $SourceOrgName -repoId $hook.publisherInputs.repository
            
                        #Try to map to target repo - Note this will have issues if target repo is in a different project and either that project's repos have not been migrated
                        if ($null -ne $hook.publisherInputs.repository -and "" -ne $hook.publisherInputs.repository) {
                            $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                            if ($null -ne $targetRepo) {
                                $hook.publisherInputs.repository = $targetRepo.id
                            }
                            else {
                                throw "Failed to locate repository [$($sourceRepo.name)] in target. "
                            }
                        }
                    }
                } 
                
                if ($hook.consumerId -eq "webHooks") {
                    if ($null -ne $hook.consumerInputs) {
                        if ($maskedValue -eq $hook.consumerInputs.basicAuthPassword) {
                            # Check hook secrets mapping for this hook's "basicAuthPassword"
                            if ($null -eq $secretsMap.serviceHooks.webHooks[$hook.consumerInputs.url] -or 
                                $null -eq $secretsMap.serviceHooks.webHooks[$hook.consumerInputs.url].basicAuthPassword) {
                                throw "Secrets mapping for WebHook - $($hook.consumerInputs.url) is missing or doesn't contain required 'basicAuthPassword' field."
                            }
                            else {
                                $hook.consumerInputs.basicAuthPassword = $secretsMap.serviceHooks.webhooks[$hook.consumerInputs.url].basicAuthPassword
                            }
                        }
                    }
                }
                
                if ($hook.consumerId -eq "jenkins") {
                    if ($null -ne $hook.consumerInputs) {
                        if ($maskedValue -eq $hook.consumerInputs.password) {
                            # Check hook secrets mapping for this hook's "password"
                            if ($null -eq $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl] -or 
                                $null -eq $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl].password) {
                                throw "Secrets mapping for Jenkins - $($hook.consumerInputs.serverBaseUrl) is missing or doesn't contain required 'password' field."
                            }
                            else {
                                $hook.consumerInputs.password = $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl].password
                            }
                        }
                        if ($maskedValue -eq $hook.consumerInputs.buildAuthToken) {
                            # Check hook secrets mapping for this hook's "buildAuthToken"
                            if ($null -eq $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl] -or 
                                $null -eq $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl].buildAuthToken) {
                                throw "Secrets mapping for Jenkins - $($hook.consumerInputs.url) is missing or doesn't contain required 'buildAuthToken' field."
                            }
                            else {
                                $hook.consumerInputs.buildAuthToken = $secretsMap.serviceHooks.jenkins[$hook.consumerInputs.serverBaseUrl].buildAuthToken
                            }
                        }
                    }
                }

                if ($hook.consumerId -eq "teams") {
                    # Take source team ID, get Team name, lookup team in target by name to get id to set subscriberId
                    foreach ($s_team in $SourceTeams) {
                        if($s_team.id -eq $hook.publisherInputs.subscriberId) {
                            foreach ($t_team in $TargetTeams) {
                                if($t_team.name -eq $s_team.name){
                                    $hook.publisherInputs.subscriberId = $t_team.id
                                    break
                                }
                            }
                        }
                    }
                }

                if (($hook.consumerId -eq "workplaceMessagingApps") -AND ($hook.publisherId -eq "pipelines")) {
                    # Take source team ID, get Team name, lookup team in target by name to get id to set subscriberId
                    foreach ($s_pipeline in $SourcePipelines) {
                        if($s_pipeline.id -eq $hook.publisherInputs.pipelineId) {
                            foreach ($t_pipeline in $TargetPipelines) {
                                if($t_pipeline.name -eq $s_pipeline.name){
                                    $hook.publisherInputs.pipelineId = $t_pipeline.id
                                    break
                                }
                            }
                        }
                    }
                }

                $servicehookJson = @{
                    "publisherId"      = $hook.publisherId
                    "eventType"        = $hook.eventType
                    "resourceVersion"  = $hook.resourceVersion
                    "consumerId"       = $hook.consumerId
                    "consumerActionId" = $hook.consumerActionId
                    "publisherInputs"  = $hook.publisherInputs
                    "consumerInputs"   = $hook.consumerInputs
                    "status"           = $hook.status
                }

                New-ServiceHook -projectName $targetProjectOrg.id -orgName $TargetOrgName -headers $targetHeaders  -serviceHook $servicehookJson
        
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
            }
        }
    }
}

