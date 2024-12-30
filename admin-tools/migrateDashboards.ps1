Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "------------------------"
Write-Log -msg "-- Migrate Dashboards --"
Write-Log -msg "------------------------"
Write-Log -msg " "

set-alias CopyDashboard "C:\wrk\ups\azure-devops-utils\CopyDashboard\CopyDashboard\bin\Debug\netcoreapp3.1\CopyDashboard.exe"

# get list of dashboards and teams from the source project
# Excute the copy dashboard command for each

$sourceHeaders = New-HTTPHeaders -pat $SourcePat
$targetHeaders = New-HTTPHeaders -pat $TargetPat

$teams = [array](Get-Teams -projectSk $sourceProjectName -org $SourceOrg -headers $sourceHeaders)

ForEach ($team in $teams) {
    Write-Log -msg "--- Dashboard: ---"
    $dashboardResults = Get-Dashboards -projectSK $sourceProjectName -org $sourceOrg -team $team.name -headers $sourceHeaders
    if ($sourceOrg.Contains("tfs")) {
        $dashboards = $dashboardResults.dashboardEntries;
    }
    else {
        $dashboards = $dashboardResults.value;
    }
    ForEach ($dashboard in $dashboards) { 
        Write-Log -msg "team: $($team.name) dashboard: $($dashboard.name) scope: copy$($dashboard.dashboardScope)" 
        #todo don't assume 1
        $targetDashboards = Get-Dashboards -projectSK $targetProjectName -org $targetOrg -team $team.name -headers $targetHeaders
        ForEach ($targetDashboard in $targetDashboards.value) {
            CopyDashboard --org $sourceOrg --pat $sourcePat --source-project "$sourceProjectName" --target-org $targetOrg `
                --target-pat $targetPat --target-project "$targetProjectName" --source-team "$($team.name)" --target-team "$($team.name)" `
                --source-dashboard "$($dashboard.name)" --target-dashboard "$($dashboard.name)" --target-dashboard-id $targetDashboard.id
        }
    }
}