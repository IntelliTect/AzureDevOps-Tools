# TODO: Need to add requiredReviewerIds mapping as seen below
#    "settings": {
#    >>> "requiredReviewerIds": ["7fbd9aa3-570f-41d1-bac5-3208840abc20", "d35c67af-9765-473b-804d-d80d6f0ab4f6", "e708e037-da6f-4bb8-8e41-2816cbf1d404", "cb58f60d-4667-4efe-b64e-9b15b6896bea"],
#        "scope": [{
#            "refName": "refs/heads/develop",
#            "matchKind": "Exact",
#            "repositoryId": "87109ee6-6b78-4295-8204-f94a46bffa2e"
#        }]
#    },

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
Write-Log -msg "----------------------"
Write-Log -msg "-- Migrate Policies --"
Write-Log -msg "----------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$policies = Get-Policies -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders
$targetRepos = Get-Repos -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg

Write-Log -msg "Found $($policies.Count) policies in source.. "  -NoNewline

foreach ($policy in $policies) {
    Write-Log -msg "Attempting to create [$($policy.id)] in target.. "  -NoNewline
    try {

        foreach ($entry in $policy.settings.scope) {
            if ($null -ne $entry.repositoryId) {
                $sourceRepo = Get-Repo -headers $sourceHeaders -org $sourceOrg -repoId $entry.repositoryId
                if ($null -eq $sourceRepo) {
                    Write-Error "Could not find $($entry.repositoryId) in source while attempting to migrate policy." -ErrorAction SilentlyContinue
                }
                $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                if ($null -eq $sourceRepo) {
                    Write-Error "Could not find $($entry.repositoryId) in target while attempting to migrate policy." -ErrorAction SilentlyContinue
                }
                $entry.repositoryId = $targetRepo.id
            }
        }

        New-Policy -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -policy @{
            "isEnabled"     = $policy.isEnabled
            "isBlocking"    = $policy.isBlocking
            "isDeleted"     = $policy.isDeleted
            "settings"      = $policy.settings
            "type"          = @{ id = $policy.type.id }
        }
        Write-Log -msg "Done!" -ForegroundColor "Green"
    }
    catch {
        Write-Log -msg "FAILED!" -ForegroundColor "Red"
        Write-Log -msg $_ -ForegroundColor "Red"
    }
}