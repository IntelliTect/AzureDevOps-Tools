param(
    [string]$sourcePat,
    [string]$sourceOrg, 
    [string]$poolType, 
    [string]$OutFile, 
    [int]$BatchSize = 50,
    [string]$LogLocation = $PSScriptRoot
)
. .\AzureDevOps-Helpers.ps1 -LogLocation $LogLocation
. .\AzureDevOps-AgentPoolHelpers.ps1

$final = @()
$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$agentPoolHelpers = "$(Get-Location)\AzureDevOps-AgentPoolHelpers.ps1"
$helpers = "$(Get-Location)\AzureDevOps-Helpers.ps1"

$poolAgents = (Get-ADOPoolsWithAgents -Headers $sourceHeaders -Org $sourceOrg -poolType $poolType)

$WorkingDir = $PSScriptRoot

Write-Log -msg "Found $($poolAgents.Count) agents.."
Write-Log -msg "Processing agents in batches of $BatchSize.."
    
$jobsBatch = @()
foreach ($poolAgent in $poolAgents) {

    if ($jobsBatch.Count -eq $BatchSize) {
        Write-Log -msg "Waiting for current batch to complete.."
            
        Wait-Job -Job $jobsBatch | Out-Null
        foreach ($job in $jobsBatch) {
            $final += Receive-Job -Job $job | ConvertFrom-Json
        }
        Write-Log -msg "Progress ($($final.Count)/$($poolAgents.Count))"
        $jobsBatch = @()
    }

    Write-Log -msg ("[$($jobsBatch.Count)] Collecting info for $($poolAgent.agentName) in $($poolAgent.poolName) ..")

    $jobsBatch += Start-Job -ArgumentList $helpers, $sourceHeaders, $sourceOrg, $poolAgent, $agentPoolHelpers -ScriptBlock {
        param ($helpers, $headers, $org, $poolAgent, $agentPoolHelpers)
        Import-Module $helpers
        Import-Module $agentPoolHelpers

        try {
            $PoolAgents = [array](Get-ADOPoolsWithAgents -headers $headers -org $Org -poolType $poolType)

            return (@{
                    "poolId"                         = $poolAgent.poolId
                    "poolName"                       = $poolAgent.poolName
                    "poolIsHosted"                   = $poolAgent.poolIsHosted
                    "poolType"                       = $poolAgent.poolType
                    "poolIsLegacy"                   = $poolAgent.poolIsLegacy
                    "agentId"                        = $poolAgent.agentId
                    "agentName"                      = $poolAgent.agentName
                    #"agentstatusChangedOn"           = $poolAgent.statusChangedOn
                    "agentVersion"                   = $poolAgent.version
                    "agentOsDescription"             = $poolAgent.osDescription
                    "agentEnabled"                   = $poolAgent.enabled
                    "agentStatus"                    = $poolAgent.status
                    "agentProvisioningState"         = $poolAgent.provisioningState
                    "agentAccessPoint"               = $poolAgent.accessPoint
                    "computerName"                   = $poolAgent.computerName
                    #"machineName"                    = $poolAgent.machineName
                    "lastCompleatedTaskFinishedTime" = $poolAgent.lastCompleatedTaskFinishedTime
                    "lastCompleatedTaskId"           =$poolAgent.lastCompleatedTaskId
                    "lastCompleatedTaskResult"       =$poolAgent.lastCompleatedTaskResult
                }) | ConvertTo-Json
        }
        catch {
            Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
            Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
            throw
        }
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
