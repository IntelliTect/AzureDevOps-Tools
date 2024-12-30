# todo: import process template
# https://docs.microsoft.com/en-us/rest/api/azure/devops/processadmin/processes/import%20process%20template?view=azure-devops-rest-5.1

# todo: replace client with InvokeRest
[Reflection.Assembly]::LoadWithPartialName('System.Net.Http')

#todo help

function init-HTTPClient([string]$pat) {
    return "not needed, refactor to use Invoke-RestMethod"
}

function Get-ADOWorkItemTypes([string]$ProcessId, [string]$WorkItemType, [string]$org) {

    # Work Items for Process
    #GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=5.0-preview.2

    $url = "$org/_apis/work/processes/$ProcessId/workitemtypes?api-version=5.0-preview.2"
    $results = $client.GetStringAsync($url)
    $workItemTypes = ($results.Result | convertfrom-json).value
    if ($WorkItemType) {
        return $workItemTypes | Where-Object {$_.name -ieq $WorkItemType}
    }
    else {
        return $workItemTypes
    }
}

function Add-ADOPicklist([string]$listFile, [string]$org) {
    # doc https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/lists/create?view=azure-devops-rest-5.1

    # POST https://dev.azure.com/{organization}/_apis/work/processes/lists?api-version=5.1-preview.1
    $url = "$org/_apis/work/processes/lists?api-version=5.1-preview.1"

    $listjson = Get-Content $listFile -Raw
    $sct = new-object System.Net.Http.StringContent($listjson, [System.Text.Encoding]::ASCII, 'application/json')
    $results = $cl.PostAsync($url, $sct)
    $results.Result
    $results.Result.Content.ReadAsStringAsync().Result
}

function Add-ADOLists([string]$workItemTypeName, [string]$org) {

    $listInputPath = Join-Path -Path $inputDir -ChildPath ($workItemTypeName + "_lists.csv")
    $newLists = import-csv $listInputPath

    $newLists | ForEach-Object {
        $listInputPath = Join-Path $inputDir -ChildPath ($_.refname + ".json")
        Add-ADOPicklist -listFile $listInputPath
    }
}

function Get-ADOLists([string]$listName, [string]$org) {

    # GET https://dev.azure.com/{organization}/_apis/work/processdefinitions/lists?api-version=4.1-preview.1
    $url = "$org/_apis/work/processdefinitions/lists?api-version=4.1-preview.1"
    $results = $client.GetStringAsync($url)
    $lists = ($results.Result | convertfrom-json).value
    if ($listName) {
        return $lists | Where-Object {$_.name -ieq $listName}
    }
    else {
        return $lists
    }
}

function Add-ADOProjectFields([string]$project, [string]$witRefName, [string]$csvFile, $lists, [string]$org) {

    $url = "$org/$project/_apis/wit/fields?api-version=5.1-preview.2"
    $baseUrl = "$org/_apis/wit/fields/"

    $newFields = import-csv $csvFile

    $newFields | ForEach-Object {

        $list = $null
        $isPickList = $false
        if ($_.picklist) {
            $pickListName = $_.picklist
            $list = $lists | Where-Object {$_.name -ieq $pickListName}
            $isPickList = $true
        }

        $field = [PSCustomObject]@{
            _links = $null
            canSortyBy = $true
            description = $null
            isIdentity = ($_.type -ieq "identity")
            isPicklist = $isPickList
            isPicklistSuggested = $false
            isQueryable = $true
            name = $_.name
            picklistId = $list.id
            readOnly = $false
            referenceName = $_.refName
            supportedOperations = $null
            type = $_.type
            url = $baseUrl + $_.refname
            usage = "workItem"
        }

        $fieldjson = $field | convertto-json
        $header = new-object System.Net.Http.StringContent($fieldjson, [System.Text.Encoding]::ASCII, 'application/json')
        $results = $client.PostAsync($url, $header)
        $results.Result
        $results.Result.Content.ReadAsStringAsync().Result
    }
}

function Add-ADOFields([string]$processId, [string]$witRefName, [string]$csvFile, $lists, [string]$org) {

    # Add Field to Process Work Item Type
    $url = "$org/_apis/work/processdefinitions/$processId/fields?api-version=4.1-preview.1"
    $baseUrl = "$org/_apis/wit/fields/"

    $newFields = import-csv $csvFile

    $newFields | ForEach-Object {

        $picklist = $null
        if ($_.picklist) {
            $pickListName = $_.picklist
            $list = $lists | Where-Object {$_.name -ieq $pickListName}
            $picklist = [PSCustomObject]@{
                id = $list.id
                isSuggested = $null
                Name = $pickListName
                type = $null
                url = $null
            }
        }

        $field = [PSCustomObject]@{
            referenceName = $_.refName
            name = $_.name
            type = $_.type
            pickList = $picklist
            readOnly = $false
            required = $false
            defaultValue = $null
            url = $baseUrl + $_.refName
            allowGroups = $null
        }

        $fieldjson = $field | convertto-json
        $header = new-object System.Net.Http.StringContent($fieldjson, [System.Text.Encoding]::ASCII, 'application/json')
        $results = $client.PostAsync($url, $header)
        $results.Result
        $results.Result.Content.ReadAsStringAsync().Result
    }
}

function Get-ADOProjectFields([string]$projectName, [string]$org, [string]$pat) {
    if (!($org)) {
        $org = $defaultOrg
    }

    $headers = (New-HTTPHeaders -pat $pat)

    $url = "$org/_apis/projects/"+$projectName+"?api-version=5.1"
    try {
        $project = Invoke-RestMethod -Method Get -uri $url -headers $headers
    }
    catch {
        write-Error "Error getting project $projectname : $_"
        return
    }

    $fieldsUrl =  "$org/"+$project.id+"/_apis/wit/fields?api-version=5.0-preview.2"
    try {
        $fields = Invoke-RestMethod -Method Get -uri $fieldsUrl -headers $headers
    }
    catch {
        write-Error "Error getting project fields for $projectname : $_"
    }

    return $fields
}

function Delete-ADOWorkItemField([string]$fieldName, [string]$org, [string]$pat) {
    #DELETE https://dev.azure.com/aiz-test/_apis/wit/fields/Custom.ARCID
    try {
        $results = Invoke-RestMethod -Method Delete -uri "$org/_apis/wit/fields/$fieldName" -headers (New-HTTPHeaders -pat $pat)
    }
    catch {
        write-Error "Error getting project fields for $projectname : $_"
    }
    return $results
}