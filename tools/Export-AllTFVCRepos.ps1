Param
(
    [string]$CollectionUrl,
    [string]$ProjectName,
    [string]$PersonalAccessToken
)

function Invoke-RestCommand {
    param(
        [string]$uri,
        [string]$commandType,
        [string]$contentType = "application/json",
        [string]$jsonBody,
        [string]$personalAccessToken
    )
	
    if ($jsonBody -ne $null) {
        $jsonBody = $jsonBody.Replace("{{","{").Replace("}}","}")
    }

    try {
        if ([String]::IsNullOrEmpty($personalAccessToken)) {
            if ([String]::IsNullOrEmpty($jsonBody)) {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -UseDefaultCredentials
            }
            else {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -UseDefaultCredentials -Body $jsonBody
            }
        }
        else {
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $personalAccessToken)))
            if ([String]::IsNullOrEmpty($jsonBody)) {            
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
            }
            else {
                $response = Invoke-RestMethod -Method $commandType -ContentType $contentType -Uri $uri -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Body $jsonBody
            }
        }

	    if ($response.count) {
		    $response = $response.value
	    }

	    foreach ($r in $response) {
		    if ($r.code -eq "400" -or $r.code -eq "403" -or $r.code -eq "404" -or $r.code -eq "409" -or $r.code -eq "500") {
                Write-Error $_
			    Write-Error -Message "Problem occurred when trying to call rest method."
			    ConvertFrom-Json $r.body | Format-List
		    }
	    }

	    return $response
    }
    catch {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Error $responseBody
        Write-Error $_
        Write-Error -Message "Exception thrown calling REST method."
	}
}

function Get-Projects {
    param
    (
        [string]$collectionUrl,
        #[string]$projectName,
        [string]$personalAccessToken
    )

    $uri = "$($collectionUrl)/_apis/projects?api-version=3.0"

    $projects = Invoke-RestCommand -uri $uri -commandType "GET" -personalAccessToken $personalAccessToken

    return $projects
}

function Get-GitRepos {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    $uri = "$($collectionUrl)/$($projectName)/_apis/git/repositories?api-version=3.0"

    $repos = Invoke-RestCommand -uri $uri -commandType "GET" -personalAccessToken $personalAccessToken

    return $repos
}

function Get-TFVCRepoSize {
    param
    (
        [string]$collectionUrl,
        [string]$projectName,
        [string]$personalAccessToken
    )

    $uri = "$($collectionUrl)/_apis/tfvc/items?scopePath=$/&recursionLevel=Full&api-version=3.0"

    $repos = Invoke-RestCommand -uri $uri -commandType "GET" -personalAccessToken $personalAccessToken
    $repoSize = 0;

     foreach($repo in $repos)
    {    
     $reposList.Add([PSCustomObject]@{
        Project = $($project.Name)
        OldGitRepoName = $($repo.Name)
        OldGitRepoSize = $($repo.size)
        OldGitUri = $($repo.RemoteUrl)
    }) | Out-Null
    } 

    foreach ($item in $items)
    {
        $repoSize = $repoSize + $item.size 

    }

    return $repoSize
}



#$CollectionUrl = "https://dev.azure.com/[yourorgname]]"
#$PersonalAccessToken = ""


$CollectionUrl = $CollectionUrl.TrimEnd("/")

$organizationName = $CollectionUrl.Substring($CollectionUrl.LastIndexOf("/") + 1)

$reposList = New-Object System.Collections.ArrayList($null)

$projects = Get-Projects -collectionUrl $CollectionUrl -personalAccessToken $PersonalAccessToken

foreach($project in $projects)
{
    $repos = Get-GitRepos -collectionUrl $CollectionUrl -projectName $Project.Name -personalAccessToken $PersonalAccessToken
    foreach($repo in $repos)
    {    
     $reposList.Add([PSCustomObject]@{
        Project = $($project.Name)
        OldGitRepoName = $($repo.Name)
        OldGitRepoSize = $($repo.size)
        OldGitUri = $($repo.RemoteUrl)
    }) | Out-Null
    } 
}
$repoSize = Get-TFVCRepoSize -collectionUrl $CollectionUrl -projectName $Project.Name -personalAccessToken $PersonalAccessToken
    
$reposList.Add([PSCustomObject]@{
    Project = "TFVC"
    OldGitRepoName = "$/"
    OldGitRepoSize = $($repoSize)
}) | Out-Null

$reposList | Export-Csv GitRepos-$($organizationName)-$($ProjectName).csv -NoTypeInformation