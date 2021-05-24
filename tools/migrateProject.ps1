Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetOrgName = $targetOrgName,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName,

    [string]$secretsMapPath = "",
    [string]$witConfigPath = "",
    [string]$WorkingDir = "$((Get-Location).Path)\_work"
)

. .\AzureDevOps-Helpers.ps1

Write-Log -msg " "
Write-Log -msg "---------------------"
Write-Log -msg "-- Migrate Project --"
Write-Log -msg "---------------------"
Write-Log -msg " "

(New-Item -Path $WorkingDir -ItemType Directory -Force) | Out-Null

Write-Log -msg "Starting migration of $sourceOrg/$sourceProjectName to $targetOrg/$targetProjectName."

# .\migrateWorkItems.ps1
# .\migrateTeamMembers.ps1 
.\migrateBuildQueues.ps1 
$repos = .\clonerepos.ps1
.\pushrepos.ps1 -repos $repos
.\migrateServiceHooks.ps1 
.\migrateServiceEndpoints.ps1 
.\migrateVariableGroups.ps1
.\migratePolicies.ps1 
.\migrateDashboards.ps1 
.\migrateBuildDefinitions.ps1
# .\migrateReleaseDefinitions.ps1
