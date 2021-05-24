param(
    [string]$sourcePat,
    [string]$sourceOrg, 
    [string]$sourceProjectName, 
    [string]$OutFile, 
    [int]$BatchSize = 50
)
. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

$final = @()
$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$projectHelpers = "$(Get-Location)\AzureDevOps-ProjectHelpers.ps1"
$helpers = "$(Get-Location)\AzureDevOps-Helpers.ps1"

$projects = (Get-ADOProjects -Headers $sourceHeaders -Org $sourceOrg -ProjectName $sourceProjectName)

Write-Log -msg "Found $($projects.Count) projects.."
Write-Log -msg "Processing projects in batches of $BatchSize.."
    
$jobsBatch = @()
foreach ($project in $projects) {

    if ($jobsBatch.Count -eq $BatchSize) {
        Write-Log -msg "Waiting for current batch to complete.."
            
        Wait-Job -Job $jobsBatch | Out-Null
        foreach ($job in $jobsBatch) {
            $final += Receive-Job -Job $job | ConvertFrom-Json
        }
        Write-Log -msg "Progress ($($final.Count)/$($projects.Count))"
        $jobsBatch = @()
    }
    Write-Log -msg "Collecting info for $($project.name)[$($jobsBatch.Count)] .."

    $jobsBatch += Start-Job -ArgumentList $helpers, $sourceHeaders, $sourceOrg, $project, $projectHelpers -ScriptBlock {
        param ($helpers, $headers, $org, $project, $projectHelpers)
        Import-Module $helpers
        Import-Module $projectHelpers

        try {
            
            $releaseDefs = [array](Get-ReleaseDefinitions -projectSk $project.id -org $Org -headers $headers)
            $buildDefs = [array](Get-BuildDefinitions -projectSk $project.id -org $Org -headers $headers)
            $queues = [array](Get-BuildQueues -projectSk $project.id -org $Org -headers $headers)
            $teams = [array](Get-Teams -projectSk $project.id -org $Org -headers $headers)
            $policies = [array](Get-Policies -projectSk $project.id -org $Org -headers $headers)
            $repos = [array](Get-ReposWithLastCommit -projectSk $project.id -org $Org -headers $headers)
            $svcEndpoints = [array](Get-ServiceEndpoints -projectSk $project.id -org $Org -headers $headers)
            $workItemCounts = Get-WorkItemCount -projectSk $project.id -org $Org -headers $headers
            $lastBuildTime = (Get-LastBuildTime -projectSk $project.id -org $Org -headers $headers)
            $lastReleaseTime = (Get-LastReleaseTime -projectSk $project.id -org $Org -headers $headers)
            
            $queueCount = ($queues | Where-Object {$_.pool.isHosted -eq $false}).Count

            if ($null -eq $queueCount) {
                $queueCount = 0
            }

            $dashboards = @()
            foreach ($team in $teams) {
                $teamDashes = Get-Dashboards -projectSk $project.id -org $Org -team $team.id -headers $headers
                foreach ($dash in $teamDashes) {
                    $dashboards += $dash
                }
            }

            $svcEndpointTypes = [System.Collections.ArrayList]@()
            $svcEndpointAuthSchemes = [System.Collections.ArrayList]@()
            foreach ($svc in $svcEndpoints) {
                if ($false -eq $svcEndpointTypes.Contains($svc.type)) {
                    $svcEndpointTypes += $svc.type
                }
                if ($null -ne $svc.authorization -and
                    $null -ne $svc.authorization.scheme -and                    
                    $false -eq $svcEndpointAuthSchemes.Contains($svc.authorization.scheme)) {
                    $svcEndpointAuthSchemes += $svc.authorization.scheme
                }
            }

            $allReposSizeMb = 0
            $largestRepo = $null
            $lastCommit = $null
            for ($i = 0; $i -lt $repos.Count; $i++) {
                $repo = $repos[$i]
                if ($null -eq $largestRepo -or $largestRepo.sizeInBytes -lt $repo.sizeInBytes) {
                    $largestRepo = $repo
                }
                if ($null -eq $lastCommit -or $lastCommit -lt $repo.lastCommit) {
                    $lastCommit = $repo.lastCommit
                }
                $allReposSizeMb += $repo.sizeInBytes / 1024 / 1024
            }
            
            if ($null -eq $largestRepo) { $largestRepo = @{name = "No Repos" } }

            return (@{
                    "id"                         = $project.id
                    "name"                       = $project.name
                    "releaseDefinitionCount"     = $releaseDefs.Count
                    "buildDefinitionCount"       = $buildDefs.Count
                    "teamCount"                  = $teams.Count
                    "policyCount"                = $policies.Count
                    "repoCount"                  = $repos.Count
                    "dashboardCount"             = $dashboards.Count
                    "largestRepoSize"            = $largestRepo.sizeInBytes 
                    "largestRepoName"            = $largestRepo.name 
                    "largestRepoProjectName"     = $largestRepo.projectName 
                    "workItemCount"              = $workItemCounts.Count
                    "workItemRevisionsCount"     = $workItemCounts.TotalRevisions
                    "workItemLastChanged"        = Get-WorkItemLastChanged -projectSk $project.id -org $Org -headers $headers
                    "serviceEndpointCount"       = $svcEndpoints.Count
                    "serviceEndpointTypes"       = $svcEndpointTypes -join ","
                    "serviceEndpointAuthSchemes" = $svcEndpointAuthSchemes -join ","
                    "serviceHookCount"           = (Get-ServiceHooks -projectSk $project.id -org $Org -headers $headers).Count
                    "allReposSizeMb"             = $allReposSizeMb
                    "lastBuildTime"              = $lastBuildTime
                    "lastReleaseTime"            = $lastReleaseTime
                    "lastCommit"                 = $lastCommit
                    "buildQueueCount"            = $queueCount
                    "testPlanCount"              = (Get-TestPlans -projectSk $project.id -org $Org -headers $headers).Count
                    "processTemplate"            = (Get-ADOProjectProperties -Headers $headers -Org $Org -projectId $project.id -propertyKey "System.Process Template").value
                }) | ConvertTo-Json
        }
        catch {
            Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
            Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
            throw
        }
    }
}

Wait-Job -Job $jobsBatch | Out-Null
foreach ($job in $jobsBatch) {
    $final += Receive-Job -Job $job | ConvertFrom-Json
}
    
Write-Log -msg "Done!"

if ($OutFile) {
    $final | Export-CSV $OutFile -NoTypeInformation
}

return $final
