[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $SourceRepoUrl,
    $SourceProjectName,
    $TargetOrganizationName,
    $PersonalAccessToken
)

function Help() {
    Write-Host "
    
 migrate-external-repos ...
    Migrate external repos to Azure DevOps
    Assumes user is already authenticated against source git host
    "
}

$modulePath = "C:\dev\AzureDevOps-Tools\modules"
Import-Module "$modulePath\Migrate-ADO-Common.psm1"
Import-Module "$modulePath\Migrate-ADO-Repos.psm1"

$repos = Get-Content .\repos.txt
$headers = New-HTTPHeaders -PersonalAccessToken $pat

$sourceProjectName = "<sourceprojectname>"
$targetProjectName = "<targetprojectname>" 
$orgName = "<orgname>"

$sourceRepoPrefix = "template source repo clone url  $sourceProjectName "
$targetRepoPrefix = "template target repo clone url /$orgName/$targetProjectName/_git"

foreach ($repo in $repos) {

    Write-Host "Cloning repo $repo"
    $sourceRepo = [uri]::EscapeUriString("$repo")

    switch ($SourceProvider) {
        "AzureDevOps" {

        }
        "GitLab" {

        }
    }

    git clone "$sourceRepoPrefix/$sourceRepo"
    git clone --mirror "$sourceRepoPrefix/$sourceRepo.git" "./$repo/.git"

    Set-Location ".\$sourceRepo"

    git fetch --all

    $targetRepo = $repo.Replace(" ", "-")
    Write-Host "Creating repo $targetRepo"
    New-GitRepository -Project $targetProjectName -OrgName $orgName -RepoName $targetRepo -Headers $headers

    Write-Host "Adding remote ..."
    git remote add ado "$targetRepoPrefix/$targetRepo"

    Write-Host "Push remote ..."
    git push -u ado --all
}