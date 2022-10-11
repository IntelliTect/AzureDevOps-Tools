
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
    [string]$version
    [string]$osDescription
    [bool]$enabled
    [string]$status
    [string]$provisioningState
    [string]$accessPoint
    poolAndAgent(){
    }
    poolAndAgent([object]$pool, [object]$agent){
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
    $url = "$org/_apis/distributedtask/pools/$PoolId/agents?api-version=5.0"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}

function Get-ADOPoolsWithAgents($Headers, [string]$Org, [string]$poolType) {
    if($poolType -eq "deployment" -or $poolType -eq "d"){
        $pools = Get-ADODeploymentPools $Headers $Org
    }else{
        $pools = Get-ADOPools $Headers $Org
    }
    
    $poolAndAgents = New-Object System.Collections.ArrayList
    foreach ($pool in $pools){
        $poolAgents = Get-ADOPoolAgents $Headers $Org $pool.id
        foreach ($agent in $poolAgents){
            $poolAndAgents.Add([poolAndAgent]::new($pool, $agent))  | Out-Null
        }
    }
    return $poolAndAgents
}
