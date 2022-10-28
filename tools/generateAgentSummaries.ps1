param(
    [string]$sourcePat,
    [string]$sourceOrg, 
    [string]$poolType, #poolTypes are "all" or "ad", "automated" or "a", "devlopment or d"
    [string]$OutFile, 
    [int]$BatchSize = 10,
    [string]$LogLocation = $PSScriptRoot
)
. .\AzureDevOps-Helpers.ps1 -LogLocation $LogLocation
. .\AzureDevOps-AgentPoolHelpers.ps1

$final = @()
$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$agentPoolHelpers = "$(Get-Location)\AzureDevOps-AgentPoolHelpers.ps1"
$helpers = "$(Get-Location)\AzureDevOps-Helpers.ps1"

$pools = New-Object System.Collections.ArrayList

if ($poolType -eq "all" -or $poolType -eq "ad" -or $poolType -eq "automated" -or $poolType -eq "a") {
        $autoPools = Get-ADOPools $sourceHeaders $sourceOrg
        foreach ($autoPool in $autoPools) {
            $pools.Add($autoPool) | Out-Null
        }
}
if ($poolType -eq "all" -or $poolType -eq "ad" -or $poolType -eq "deployment" -or $poolType -eq "d") {
        $buildPools = Get-ADODeploymentPools $sourceHeaders $sourceOrg
        foreach ($buildPool in $buildPools) {
            $pools.Add($buildPool) | Out-Null
        }
}

$WorkingDir = $PSScriptRoot
Write-Log -msg "Found $($pools.Count) pools.."
Write-Log -msg "Processing pools in batches of $BatchSize.."
    
$jobsBatch = @()
foreach ($pool in $pools) {

    if ($jobsBatch.Count -eq $BatchSize) {
        Write-Log -msg "Waiting for current batch to complete.."
            
        Wait-Job -Job $jobsBatch | Out-Null
        foreach ($job in $jobsBatch) {
            $final += Receive-Job -Job $job | ConvertFrom-Json
        }
        Write-Log -msg "Progress (Proccessed $($final.Count) agents..)"
        $jobsBatch = @()
    }
   
            Write-Log -msg ("[$($jobsBatch.Count)] Collecting info for $($pool.Name) ..")

            $jobsBatch += Start-Job -ArgumentList $sourceHeaders, $sourceOrg, $pool, $agentPoolHelpers, $helpers -ScriptBlock {
                param ($sourceHeaders, $sourceOrg, $pool, $agentPoolHelpers, $helpers)
                Import-Module $agentPoolHelpers
                Import-Module $Helpers


                $agents = [array](Get-ADOPoolAgents $sourceHeaders $sourceOrg $pool.id)
                Write-Log -msg "Found $($agents.Count) agents in $($pool.Name).."
                
                $info = @()

                foreach($agent in $agents){
                
                    Write-Log -msg ("Parsing $($agent.name) in $($pool.Name) ..")
                
                    try {
                           $info += (@{
                                    "poolId"                            = $pool.Id
                                    "poolName"                          = $pool.Name
                                    "poolIsHosted"                      = $pool.IsHosted
                                    "poolType"                          = $pool.poolType
                                    "poolIsLegacy"                      = $pool.IsLegacy
                                    "agentId"                           = $agent.id
                                    "agentName"                         = $agent.name
                                    "agentVersion"                      = $agent.version
                                    "agentOsDescription"                = $agent.osDescription
                                    "agentEnabled"                      = $agent.enabled
                                    "agentStatus"                       = $agent.status
                                    "agentProvisioningState"            = $agent.provisioningState
                                    "agentAccessPoint"                  = $agent.accessPoint
                                    "computerName"                      = $agent.systemCapabilities."Agent.ComputerName"
                                    "lastCompleatedRequestFinishedTime" = $agent.lastCompletedRequest.finishTime
                                    "lastCompleatedRequestId"           = $agent.lastCompletedRequest.requestId
                                    "lastCompleatedRequestResult"       = $agent.lastCompletedRequest.result
                                }) | ConvertTo-Json
                    }
                    catch {
                        Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
                        Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
                        throw
                    }
            }
            return $info
        }
}

Wait-Job -Job $jobsBatch | Out-Null
foreach ($job in $jobsBatch) {
    $final += Receive-Job -Job $job | ConvertFrom-Json
}
    
Write-Log -msg "Done!"

if ($OutFile) {
    $final | Export-CSV $OutFile -NoTypeInformation
}

return $final
