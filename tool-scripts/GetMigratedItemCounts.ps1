
Param (
        [Parameter (Mandatory=$TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory=$TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetPAT,
        [Parameter (Mandatory=$TRUE)] [String[]]$QueryBits
)


Write-Host "Begin GET Migrated Work-Item Counts.."
Write-Host " "

 # Create Headers
$sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
$targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

$sourceTotal = 0
$targetTotal = 0
$differTotal = 0


$counter = 1
foreach($qBit in $QueryBits)
{

        $sourceUrl = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/wit/wiql?api-version=7.0"
        $sourceBody = "{""query"": ""SELECT [System.Id], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$SourceProjectName' AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') $qBit ORDER BY [System.ChangedDate] desc""}"
        $sourceResult = $NULL
        try {
                $sourceResult = Invoke-RestMethod -Method Post -uri $sourceUrl -Headers $sourceHeaders -Body $sourceBody -ContentType "application/json"
                $sourceCount = $sourceResult.workItems.Count
                # $sourceCounts.Add($sourceCount)
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }


        $targetUrl = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/wit/wiql?api-version=7.0"
        $targetBody = "{""query"": ""SELECT [System.Id], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$TargetProjectName' AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') $qBit ORDER BY [System.ChangedDate] desc""}"
        $targetResult = $NULL
        try {
                $targetResult = Invoke-RestMethod -Method Post -uri $targetUrl -Headers $targetHeaders -Body $targetBody -ContentType "application/json"
                $targetCount = $targetResult.workItems.Count
                # $targetCounts.Add($targetCount)
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }

        $difference = $sourceCount - $targetCount
        Write-Host "Query Bit $($counter.ToString().PadLeft(2,' ')): Source Count = $($sourceCount.ToString().PadLeft(6,' ')) : Target Count = $($targetCount.ToString().PadLeft(6,' ')) : Difference = $($difference.ToString().PadLeft(6,' '))"
        $counter += 1
        $sourceTotal += $sourceCount
        $targetTotal += $targetCount
        $differTotal += $difference
}

Write-Host "---------------------------------------------------------------------------------"
Write-Host "Totals      : Source Total = $($sourceTotal.ToString().PadLeft(6,' ')) : Target Total = $($targetTotal.ToString().PadLeft(6,' ')) : Diff Total = $($differTotal.ToString().PadLeft(6,' '))"
Write-Host " "
Write-Host "End GET Migrated Work-Item Counts.."

