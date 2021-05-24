Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName,

    [string]$consumer = $null,

    [string]$secretsMapPath = ""
)
. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "---------------------------"
Write-Log -msg "-- Migrate Service Hooks --"
Write-Log -msg "---------------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$targetRepos = Get-Repos -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg

$maskedValue = "********"

if ($secretsMapPath -ne "") {
    $secretsMap = ((Get-Content -Raw -Path $secretsMapPath) | ConvertFrom-Json) | ConvertTo-HashTable
    Write-Log -msg "Loaded secrets map from $secretsMapPath"    
}
else {
    $secretsMap = @{
        serviceHooks = @{
            webHooks = @{}
            jenkins  = @{}
        }
    }
    Write-Log -msg "Loaded default secrets map"
}

$hooks = Get-ServiceHooks -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders

Write-Log -msg "Located $($hooks.Count) in source."

$hooks | ConvertTo-Json -depth 10 | Out-File -FilePath "hooks.json"

foreach ($hook in $hooks) {
    
    if ($null -ne $consumer -and $consumer -ne $hook.consumerId) {
        #continue
    }

    Write-Log -msg "Attempting to create [$($hook.id)] in target.. "  -NoNewline
    try {
        if ($null -ne $hook.publisherInputs -and $null -ne $hook.publisherInputs.repository) {
            $hook.publisherInputs.projectId = $targetProject.id

            $sourceRepo = Get-Repo -headers $sourceHeaders -org $sourceOrg -repoId $hook.publisherInputs.repository

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

        New-ServiceHook -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -serviceHook @{
            "publisherId"      = $hook.publisherId
            "eventType"        = $hook.eventType
            "resourceVersion"  = $hook.resourceVersion
            "consumerId"       = $hook.consumerId
            "consumerActionId" = $hook.consumerActionId
            "publisherInputs"  = $hook.publisherInputs
            "consumerInputs"   = $hook.consumerInputs
            "status"           = $hook.status
        }

        Write-Log -msg "Done!" -ForegroundColor "Green"
    }
    catch {
        Write-Log -logLevel "ERROR"  -msg "FAILED!" -ForegroundColor "Red"
        Write-Log -logLevel "ERROR"  -msg $_.Exception -ForegroundColor "Red"
        try {
            Write-Log -logLevel "ERROR"  -msg ($_ | ConvertFrom-Json).message -ForegroundColor "Red"
        }
        catch {
            
        }
    }
}
