Param(
    [string]$Query = "countByType",
    [string]$Organization = "IntelliTect-Samples",
    [string]$PersonalAccessToken
)

$queries = @{
    'countByType' = "$organization/_odata/v3.0-preview/WorkItems?`$apply=groupby((WorkItemType),aggregate(`$count as Count))"
    'countTypeByProject' = "$organization/_odata/v3.0-preview/WorkItems?`$apply=groupby((ProjectSK,WorkItemType),aggregate(`$count as Count))"
    'projectList' = "$organization/_odata/v3.0-preview/Projects?`$select=ProjectSK,ProjectName"
}

#todo help

function init-HTTPHeaders([string]$pat) {
    if (!($pat)) {
        throw "Azure DevOps PAT must be provided"
    }
    $authToken = [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes([string]::Format("{0}:{1}", "", $pat)))
    $headers = @{'Authorization' = "Basic $authToken"}
    return $headers
}

$headers = init-HTTPHeaders($PersonalAccessToken)

$queryUri = $queries[$Query]
Write-Verbose "Query uri: $queryUri"
$result = Invoke-RestMethod -Method 'get' -Uri $queryUri -Headers $headers
Write-Verbose "Result: $result"

return $result.value
