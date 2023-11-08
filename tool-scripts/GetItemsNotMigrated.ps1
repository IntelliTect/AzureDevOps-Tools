
Param (
        [Parameter (Mandatory=$TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory=$TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetPAT,
        [Parameter (Mandatory=$TRUE)] [String]$QueryBit
)


Write-Host "Begin GET Work-Items in Source that did not migrate to target.."
Write-Host " "

 # Create Headers
$sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
$targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

$sourceIds = [System.Collections.ArrayList]::new()
$targetIds = [System.Collections.ArrayList]::new()
$migratedIds = [System.Collections.ArrayList]::new()
 

$sourceUrl = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/wit/wiql?api-version=7.0"

$sourceBody = "{""query"": ""SELECT [System.Id], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$SourceProjectName' AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') $QueryBit ORDER BY [System.ChangedDate] desc""}"

$sourceResult = $NULL
try {
    $sourceResult = Invoke-RestMethod -Method Post -uri $sourceUrl -Headers $sourceHeaders -Body $sourceBody -ContentType "application/json"
    $sourceItems = $sourceResult.workItems | Select-Object -ExpandProperty id
    $sourceIds.AddRange($sourceItems)
}
catch {
    Write-Log -Message "FAILED!" -LogLevel ERROR
    Write-Log -Message $_.Exception -LogLevel ERROR
    try {
        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
    } catch {}
}



$itemQueryStrings = @()
if($NULL -ne $sourceResult)
{
        $counter = 1
        $itemQueryString = ""
        foreach ($workitem in $sourceResult.workItems) {
                $reflectedWorkItem = "'https://dev.azure.com/$SourceOrgName/$SourceProjectName/_workitems/edit/$($workitem.id)'"

                if($counter % 100 -eq 0) {
                        $itemQueryString += $reflectedWorkItem
                        $itemQueryStrings += $itemQueryString 
                        $itemQueryString = ""
                } else {
                        if($counter -ne $sourceResult.workitems.Count) {
                                $reflectedWorkItem = $reflectedWorkItem + ","
                        }
                        $itemQueryString += $reflectedWorkItem
                }

                $counter += 1
        }
        $itemQueryStrings += $itemQueryString
}

Write-Log -Message "Validating if Source items migrated to Target.."

try {
        Write-Log -Message "Obtaining items in Target by ReflectedWorkItemId.."
        foreach($queryString in $itemQueryStrings) {
                Write-Host "." -NoNewline

                $targetUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/wit/wiql?api-version=7.0"

                $targetBody = "{""query"": ""SELECT [System.Id], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$TargetProjectName' AND [Custom.ReflectedWorkItemID] IN ($queryString) ORDER BY [System.ChangedDate] desc""}"
                
                $targetResult = Invoke-RestMethod -Method Post -uri $targetUrl -Headers $targetHeaders -Body $targetBody -ContentType "application/json"
                
                $targetItems = $targetResult.workItems | Select-Object -ExpandProperty id
                if($NULL -ne $targetItems) {
                        $targetIds.AddRange($targetItems)
                }
        }
        Write-Host "."
}
catch {
        Write-Log -Message "FAILED!" -LogLevel ERROR
        Write-Log -Message $_.Exception -LogLevel ERROR
        try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
        } catch {}
}


$idQueryStrings = @()
if (($NULL -ne $targetIds) -and ($targetIds.Count -gt 0))
{
        $counter = 1
        $idQueryString = ""
        foreach ($targetId in $targetIds) {
                $idString = "$targetId"

                if($counter % 200 -eq 0) {
                        $idQueryString += $idString
                        $idQueryStrings += $idQueryString 
                        $idQueryString = ""
                } else {
                        if($counter -ne $targetIds.Count) {
                                $idString = $idString + ","
                        }
                        $idQueryString += $idString
                }

                $counter += 1
        }
        $idQueryStrings += $idQueryString 
}


try {
        if ($idQueryStrings.Count -gt 0) {
                Write-Log -Message "Obtaining items in Target by new Target Ids.."
                foreach($idString in $idQueryStrings) {
                        Write-Host "." -NoNewline

                        $migratedUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/wit/workitems?ids=$($idString)&api-version=7.0"

                        $migratedResult = Invoke-RestMethod -Method GET -uri $migratedUrl -Headers $targetHeaders -ContentType "application/json"

                        $migratedItems = $migratedResult.Value.Fields | Select-Object -ExpandProperty Custom.ReflectedWorkItemID | Select-Object @{ Name='id';Expression={ $_.Substring($_.LastIndexOF('/') + 1, $_.Length - 1 - $_.LastIndexOF('/'))} } | Select-Object -ExpandProperty id

                        if($NULL -ne $targetItems) {
                                $migratedIds.AddRange($migratedItems)
                        }

                }
                Write-Host "."
        }
}
catch {
        Write-Log -Message "FAILED!" -LogLevel ERROR
        Write-Log -Message $_.Exception -LogLevel ERROR
        try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
        } catch {}
}

Write-Log -Message "Comparing Source Ids to Target IDs.."


$diffItems = ($sourceIds | Where-Object { $_ -notin $migratedIds })

Write-Host "$($diffItems.Count) Items failed to migrate..."

Write-Host "End GET Work-Items in Source that did not migrate to target... "

$diffItems
