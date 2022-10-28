
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
