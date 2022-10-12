
class poolAndAgent {
    #pool info
    [int]$poolId
    [string]$poolName
    [bool]$poolIsHosted
    [string]$poolType
    [bool]$poolIsLegacy
    #agent info
    [string]$createdOn
    [string]$statusChangedOn
    [int]$agentId
    [string]$agentName
    [string]$computerName
    [string]$machineName
    [string]$version
    [string]$osDescription
    [bool]$enabled
    [string]$status
    [string]$provisioningState
    [string]$accessPoint
    [string]$lastCompleatedTaskFinishedTime
    [int]$lastCompleatedTaskId
    [string]$lastCompleatedTaskResult
    poolAndAgent() {
    }
    poolAndAgent([object]$pool, [object]$agent) {
        #pool info
        $this.poolId = $pool.Id
        $this.poolName = $pool.Name
        $this.poolIsHosted = $pool.IsHosted
        $this.poolType = $pool.poolType
        $this.poolIsLegacy = $pool.IsLegacy
        #agent info
        $this.createdOn = $agent.createdOn
        $this.statusChangedOn = $agent.statusChangedOn
        $this.agentId = $agent.id
        $this.agentName = $agent.name
        $this.version = $agent.version
        $this.osDescription = $agent.osDescription
        $this.enabled = $agent.enabled
        $this.status = $agent.status
        $this.provisioningState = $agent.provisioningState
        $this.accessPoint = $agent.accessPoint
        $this.computerName = $agent.systemCapabilities.COMPUTERNAME
        $this.machineName = $agent.systemCapabilities.MACHINENAME
        $this.lastCompleatedTaskFinishedTime = $agent.lastCompletedRequest.finishTime
        $this.lastCompleatedTaskId = $agent.lastCompletedRequest.requestId
        $this.lastCompleatedTaskResult = $agent.lastCompletedRequest.result
    }
}

function Get-ADOPools ($Headers, [string]$Org) {
    $url = "$org/_apis/distributedtask/pools?api-version=5.0"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}

function Get-ADODeploymentPools ($Headers, [string]$Org) {
    $url = "$org/_apis/distributedtask/pools?poolType=deployment&api-version=5.0"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}

function Get-ADOPoolAgents($Headers, [string]$Org, [int]$PoolId) {
    $url = "$org/_apis/distributedtask/pools/$PoolId/agents?includeCapabilities=true&includeLastCompletedRequest=true&api-version=5.0"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}

function Get-ADOPoolsWithAgents($Headers, [string]$Org, [string]$poolType) {
    
    $poolAndAgents = New-Object System.Collections.ArrayList
    
    if ($poolType -eq "all" -or $poolType -eq "a") {
        $pools = Get-ADOPools $Headers $Org
        
        foreach ($pool in $pools) {
            if(-not $pool.IsHosted){
                $poolAgents = Get-ADOPoolAgents $Headers $Org $pool.id
                foreach ($agent in $poolAgents) {
                    $poolAndAgents.Add([poolAndAgent]::new($pool, $agent))  | Out-Null
                }
            }
        }

        $pools = Get-ADODeploymentPools $Headers $Org
        foreach ($pool in $pools) {
            if(-not $pool.IsHosted){
                $poolAgents = Get-ADOPoolAgents $Headers $Org $pool.id
                foreach ($agent in $poolAgents) {
                    $poolAndAgents.Add([poolAndAgent]::new($pool, $agent))  | Out-Null
                }
            }
        }
    }
    else {
        if ($poolType -eq "deployment" -or $poolType -eq "d") {
            $pools = Get-ADODeploymentPools $Headers $Org
        }
        else {
            $pools = Get-ADOPools $Headers $Org
        }
    
        foreach ($pool in $pools) {
            if(-not $pool.IsHosted){
                $poolAgents = Get-ADOPoolAgents $Headers $Org $pool.id
                foreach ($agent in $poolAgents) {
                    $poolAndAgents.Add([poolAndAgent]::new($pool, $agent))  | Out-Null
                }
            }
        }
    }
    return $poolAndAgents
}
