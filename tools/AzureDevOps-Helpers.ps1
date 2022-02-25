[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $LogLocation = $PSScriptRoot
)
#todo help

function New-HTTPHeaders([string]$pat) {
    if (!($pat)) {
        throw "Azure DevOps PAT must be provided"
    }
    $authToken = [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes([string]::Format("{0}:{1}", "", $pat)))
    $headers = @{'Authorization' = "Basic $authToken"}
    return $headers
}

function Get-ADOProcesses($Headers, [string]$Org, [string]$ProcessName)  {

    $url = "$org/_apis/work/processes?api-version=5.0-preview.2"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    if ($ProcessName) {
        return $results.value | Where-Object {$_.name -ieq $ProcessName}
    }
    else {
        return $results.value
    }
}

function Get-ADOProjects($Headers, [string]$Org, [string]$ProjectName) {
    if ($ProjectName) {
        $url = "$org/_apis/projects/$ProjectName"
        return Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    }
    else {
        $url = "$org/_apis/projects?`$top=600&api-version=5.1"
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
        return $results.value
    }
}

function Get-ADOProjectProperties($Headers, [string]$Org, [string]$ProjectId, [string]$PropertyKey) {
    # GET https://dev.azure.com/fabrikam/_apis/projects/{projectId}/properties?keys=System.CurrentProcessTemplateId,*SourceControl*&api-version=5.1-preview.1

    $keys=""
    if ($PropertyKey) {
        $keys="keys=$PropertyKey"
    }
    $url = "$org/_apis/projects/$ProjectId/properties?$keys&api-version=5.1-preview.1"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    if ($ProjectName) {
        return $results.value | Where-Object {$_.name -ieq $ProjectName}
    }
    else {
        return $results.value
    }
}

function Get-ADOProjectProcessTemplates($Headers, [string]$Org) {
    $projectTemplates = @()

    $projects = Get-ADOProjects -Headers $Headers -Org $Org
    $projects | ForEach-Object {
        $template =  Get-ADOProjectProperties -Headers $headers -Org $org -ProjectId $_.id -PropertyKey "System.Process Template"
        $projectTemplates +=  [PSCustomObject]@{
            Name = $_.Name
            Template = $template[0].value
        }
        
    }
    return $projectTemplates
}



function Get-AllRepos([string]$org) {

    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/commits?api-version=5.0
    $url = "$org/_apis/git/repositories?api-version=5.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}

function Get-Teams([string]$org, $headers) {

    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/commits?api-version=5.0
    $url = "$org/_apis/teams?`$top=5000"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    return $results.value
}


function Get-AllReposWithLastCommit([string]$listName, [string]$org) {
    $final = New-Object System.Collections.ArrayList
    $repos = Get-Repos -org $org

    foreach ($repo in $repos) {
        $repoId = $repo.id
        $url = "$org/_apis/git/repositories/$repoId/commits?api-version=5.1"
        
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
        
        if ($results.value.Count -gt 0) {
            $final.Add(@{
                "id" = $repo.id
                "name" = $repo.name
                "sizeInBytes" = $repo.size
                "sizeInMegaBytes" = [math]::Round($repo.size / 1024 / 1024, 6)
                "projectName" = $repo.project.name
                "projectId" = $repo.project.id
                "lastCommit" = $results.value[0].committer.date
            })
        } else {
            $final.Add(@{
                "id" = $repo.id
                "name" = $repo.name
                "sizeInBytes" = $repo.size
                "sizeInMegaBytes" = [math]::Round($repo.size / 1024 / 1024, 6)
                "projectName" = $repo.project.name
                "projectId" = $repo.project.id
                "lastCommit" = null
            })
        }

    }
    return $final
}

function New-GitRepository($org, $projectId, $repoName, $pat) {

    #"POST https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.1"
    $url = "$org/_apis/git/repositories?api-version=5.1"

    $requestBody = @{
        name = $repoName
        project = @{
            id = $projectId
        }
    } | ConvertTo-Json

    try {
        $results = Invoke-RestMethod -Method post -uri $url -Headers (New-HTTPHeaders -pat $pat) -Body $requestBody -ContentType 'application/json'
    }
    catch {
        Write-Log -msg "Error_ $($_.Exception) creating repo $repoName in project $projectId" 
    }

}

function Delete-WorkItemById($headers, $org, $projectName, $workItemId, $destroy) {
    # DELETE https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?destroy={destroy}&api-version=5.1

    $destroyTerm = ""
    if ($destroy) {
        $destroyTerm = "destroy=$destroy&"
    }

    "workitemid is $workItemId"
    $url = "$org/$projectName/_apis/wit/workitems/"+$workItemId+"?$destroyTerm&api-version=5.1"
    $url
    
    try {
        $results = Invoke-RestMethod -Method Delete -uri $url -Headers $headers
    }
    catch {
        Write-Log -msg "Error_ $($_.Exception) creating repo $repoName in project $projectId" 
    }
    return $results

}

function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
 
    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }
 
        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )
 
            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) { ## If the object has properties that need enumeration
            ## Convert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        } else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}

function ConvertTo-Object {

    begin { $object = New-Object Object }
    
    process {
    
    $_.GetEnumerator() | ForEach-Object { Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value }  
    
    }
    
    end { $object }
    
    }

function Write-Log([string]$msg, [string]$logLevel = "INFO", $ForegroundColor = $null ) {
    $currentColor = [System.Console]::ForegroundColor
    $path = "$LogLocation\migration-$($logLevel.ToLower()).log"
    $masterpath = "$LogLocation\migration.log" 

    if ($null -eq $ForegroundColor) {
        $ForegroundColor = $currentColor
    }

    Write-Host $msg -ForegroundColor $ForegroundColor

    Write-Log-Async $msg $logLevel $path $true
    Write-Log-Async $msg $logLevel $masterpath $true
}

function Write-Log-Async
{
    param
    (
        [Parameter(Mandatory = $true,
                   Position = 0)]
        [ValidateNotNull()]
        [string]$text,
        [Parameter(Mandatory = $true,
                   Position = 1)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$level,
        [Parameter(Mandatory = $true,
                   Position = 2)]
        [string]$log,
        [Parameter(Position = 3)]
        [boolean]$UseMutex
    )
    
    Write-Verbose "Log:  $log"
    $date = (get-date).ToString()
    if (Test-Path $log)
    {
        if ((Get-Item $log).length -gt 5mb)
        {
            $filenamedate = get-date -Format 'MM-dd-yy hh.mm.ss'
            $archivelog = ($log + '.' + $filenamedate + '.archive').Replace('/', '-')
            copy-item $log -Destination $archivelog
            Remove-Item $log -force
            Write-Verbose "Rolled the log."
        }
    }
    $line = "[$date] [$level] $text"
    if ($UseMutex)
    {
        $LogMutex = New-Object System.Threading.Mutex($false, "LogMutex")
        $LogMutex.WaitOne()|out-null
        
        $line | out-file -FilePath $log -Append
        $LogMutex.ReleaseMutex()|out-null
    }
    else
    {
        $line | out-file -FilePath $log -Append
    }
}

