Param(
    [string]$Organization = "IntelliTect-Samples",
    [string]$PersonalAccessToken
)

#. ./AzureDevOps-Helpers.ps1

function Get-ServiceHooks([string]$projectSk, [string]$org, $headers) {
    $url = "$org/_apis/hooks/subscriptionsquery?api-version=5.1"
    
    $body = @{
        "publisherInputFilters" = @(
            @{
                "conditions" = @(
                    @{
                        "inputId"    = "projectId"
                        "inputValue" = $projectSk
                    }
                )
            }
        )
    }
    $temp = $body | ConvertTo-Json -Depth 10
    
    $results = Invoke-RestMethod -Method "POST" -uri $url -Headers $headers -Body $temp -ContentType "application/json"
    
    return , $results.results
}

function Get-WorkItemCount([string]$projectSk, [string]$org, $headers) {
    $analyticsOrg = $org.ToString().Replace("dev.azure.com", "analytics.dev.azure.com")
    $url = "$analyticsOrg/$projectSk/_odata/v3.0-preview/WorkItems?`$apply=aggregate(`$count as Count, Revision with sum as TotalRevisions)"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value[0]
    
}

function Get-WorkItemLastChanged([string]$projectSk, [string]$org, $headers) {
    ## $organization/_odata/v3.0-preview/WorkItems?`$apply=groupby((WorkItemType),aggregate(`$count as Count))
    $analyticsOrg = $org.ToString().Replace("dev.azure.com", "analytics.dev.azure.com")
    $url = "$analyticsOrg/$projectSk/_odata/v3.0-preview/WorkItems?`$apply=aggregate(ChangedDate with max as LastChangedDate)"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value[0].LastChangedDate
    
}

function Get-ReposWithLastCommit([string]$projectSk, [string]$org, $headers) {
    $final = @()
    $repos = Get-Repos -org $org -projectSk $projectSk -headers $headers

    foreach ($repo in $repos) {
        $repoId = $repo.id
        $url = "$org/$projectSk/_apis/git/repositories/$repoId/commits?api-version=5.1"
        
        $commits = Invoke-RestMethod -Method Get -uri $url -Headers $headers
        
        if ($commits.count -gt 0) {
            
            $final += @{
                "id"              = $repo.id
                "name"            = $repo.name
                "sizeInBytes"     = $repo.size
                "sizeInMegaBytes" = [math]::Round($repo.size / 1024 / 1024, 6)
                "projectName"     = $repo.project.name
                "projectId"       = $repo.project.id
                "lastCommit"      = $commits.value[0].committer.date
            }
        }
        else {
            
            $final += @{
                "id"              = $repo.id
                "name"            = $repo.name
                "sizeInBytes"     = $repo.size
                "sizeInMegaBytes" = [math]::Round($repo.size / 1024 / 1024, 6)
                "projectName"     = $repo.project.name
                "projectId"       = $repo.project.id
                "lastCommit"      = $null
            }
        }

    }
    return $final
}
function Get-Repos([string]$projectSk, [string]$org, $headers) {

    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/commits?api-version=5.0
    $url = "$org/$projectSk/_apis/git/repositories?api-version=5.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    if ($ProcessName) {
        return $results.value | Where-Object { $_.name -ieq $ProcessName }
    }
    else {
        return , $results.value
    }
}
function Get-Repo([string]$projectSk, [string]$org, $headers, $repoId) {

    $url = "$org/$projectSk/_apis/git/repositories/$repoId"
    
    return Invoke-RestMethod -Method Get -uri $url -Headers $headers
}
function Get-ProjectProperties([string]$projectSk, [string]$org, $headers) {

    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/commits?api-version=5.0
    $url = "$org/_apis/projects/$projectSk/properties?api-version=5.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    foreach ($pair in $results.value) {

    }
}

function Get-Releases([string]$projectSk, [string]$org, $headers) {
    $temporg = $org.ToString().Replace("dev.azure.com", "vsrm.dev.azure.com")

    $url = "$temporg/$projectSk/_apis/release/releases?api-version=5.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}

function Get-ServiceEndpoints([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/serviceendpoint/endpoints"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}

function Get-ServiceEndpoint([string]$projectSk, [string]$org, $headers, $serviceEndpointId) {

    $url = "$org/$projectSk/_apis/serviceendpoint/endpoints/$serviceEndpointId"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results

}

function New-ServiceEndpoint([string]$projectSk, [string]$org, $serviceEndpoint, $headers) {

    $url = "$org/$projectSk/_apis/serviceendpoint/endpoints?api-version=5.1-preview.2"
    
    $body = $serviceEndpoint | ConvertTo-Json

    $results = Invoke-RestMethod -ContentType "application/json" -Method Post -uri $url -Headers $headers -Body $body 
    
    return $results

}

function New-ServiceHook([string]$projectSk, [string]$org, $serviceHook, $headers) {

    $url = "$org/_apis/hooks/subscriptions?api-version=5.1"
    
    $body = $serviceHook | ConvertTo-Json

    $results = Invoke-RestMethod -ContentType "application/json" -Method Post -uri $url -Headers $headers -Body $body 
    
    return $results

}


function Get-ReleaseDefinitions([string]$projectSk, [string]$org, $headers) {
    $temporg = $org.ToString().Replace("dev.azure.com", "vsrm.dev.azure.com")

    $url = "$temporg/$projectSk/_apis/release/definitions?api-version=5.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}


function Get-LastBuildTime([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/build/builds?api-version=5.1&queryOrder=finishTimeDescending&`$top=1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    
    if ($results.count -gt 0) { return $results.value[0].finishTime } else { return $null }

}


function Get-LastReleaseTime([string]$projectSk, [string]$org, $headers) {
    $temporg = $org.ToString().Replace("dev.azure.com", "vsrm.dev.azure.com")

    $url = "$temporg/$projectSk/_apis/release/releases?api-version=5.1&queryOrder=descending&`$top=1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    if ($results.count -gt 0) { return $results.value[0].createdOn } else { return $null }

}

function Get-Builds([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/build/builds?api-version=5.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}


function Get-BuildDefinitions([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/build/definitions?api-version=5.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results.value
}

function Get-FilesWithHardcodedRepoNames([string]$projectSk, [string] $projectName,  [string]$org, $headers) {
    $tempOrg = $org.ToString().Replace("dev.azure.com", "almsearch.dev.azure.com")

    $url = "$temporg/$projectSk/_apis/search/codesearchresults?api-version=7.1"

    $Json = @"
{
  "searchText": "ext:yml AND (\"repository:\" OR \"checkout:\") AND NOT \"checkout: self\"", 
  "`$skip":  0,
  "`$top":  250,
  "filters": {
    "Project": [
      "$projectName"
    ]
  }
}
"@    
    Write-Host $Json

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $Json -ContentType "application/json"

    return $results
}


function Get-VariableGroups([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/distributedtask/variablegroups?api-version=5.1-preview"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results.value
}


function Get-VariableGroup([string]$projectSk, [string]$org, $headers, $groupId) {

    $url = "$org/$projectSk/_apis/distributedtask/variablegroups/$groupId"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}


function New-VariableGroup([string]$projectSk, [string]$org, $headers, $group) {

    $url = "$org/$projectSk/_apis/distributedtask/variablegroups?api-version=5.1-preview.1"
    
    $body = $group | ConvertTo-Json

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}


function Get-BuildQueues([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/distributedtask/queues?api-version=5.1-preview"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results.value
}


function New-BuildQueue([string]$projectSk, [string]$org, $headers, $queue) {

    $url = "$org/$projectSk/_apis/distributedtask/queues?api-version=5.1-preview&authorizePipelines=true"
    
    $body = $queue | ConvertTo-Json

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}


function New-Policy([string]$projectSk, [string]$org, $headers, $policy) {

    $url = "$org/$projectSk/_apis/policy/configurations?api-version=5.0"
    
    $body = $policy | ConvertTo-Json -Depth 10

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}


function Get-BuildDefinition([string]$projectSk, [string]$org, $headers, $buildDefinitionId, $revision = $null) {

    $url = "$org/$projectSk/_apis/build/definitions/$buildDefinitionId`?api-version=5.1"

    if ($null -ne $revision) {
        $url = "$url&revision=$revision"
    }
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}


function Save-BuildDefinition([string]$projectSk, [string]$org, $headers, $buildDefinition, $revision = 1) {

    if ($revision -gt 1) {
        
        $url = "$org/$projectSk/_apis/build/definitions/$($buildDefinition.id)?api-version=5.0-preview.6"

        $buildDefinition.revision = $revision - 1
    
        $body = $buildDefinition | ConvertTo-Json -Depth 20

        $results = Invoke-RestMethod -Method Put -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
        return $results
    }
    else {
        
        $url = "$org/$projectSk/_apis/build/definitions?api-version=5.0"
    
        $body = $buildDefinition | ConvertTo-Json -Depth 20

        $body | Out-File -FilePath "builddef-$($buildDefinition.name)-POST.json"
        try {
                $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
                return $results
        } catch {
            Write-Error -Message $_
            throw $_
        }
    } 
}


function Get-Policies([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/policy/configurations?api-version=5.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}
function Get-TestPlans([string]$projectSk, [string]$org, $headers) {

    $url = "$org/$projectSk/_apis/testplan/plans?api-version=5.1-preview.1"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}

function Get-Dashboards([string]$projectSk, [string]$org, [string]$team, $headers) {

    if ($team) {
        $url = "$org/$projectSk/$team/_apis/dashboard/dashboards"
    }
    else {
        $url = "$org/$projectSk/_apis/dashboard/dashboards"
    }
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}

function Get-DashboardDetails([string]$project, [string]$org, [string]$team, [string]$dashboardId, $headers) {

    $url = "$org/$project/$team/_apis/dashboard/dashboards/$dashboardId"

    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results

}

function Get-Teams([string]$projectSk, [string]$org, $headers) {

    $url = "$org/_apis/projects/$projectSk/teams?api-version=5.1&`$top=1000"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results.value
}

function Get-AllTeams([string]$org, [string]$pat) {

    $url = "$org/_apis/teams?api-version=5.1-preview.3&`$top=1000"
    $url

    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    }
    catch {
        Write-Error "Error getting all teams for org $org : $_"
    }
    
    return $results
}

function Get-TeamMembers([string]$team, [string]$project, [string]$org, [string]$pat) {
    $url = "$org/_apis/projects/$project/teams/$team/members?`$top=1000&api-version=5.1"

    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    }
    catch {
        Write-Error "Error getting team members for team $team from $project in org $org : $_"
    }
    
    return $results
}
