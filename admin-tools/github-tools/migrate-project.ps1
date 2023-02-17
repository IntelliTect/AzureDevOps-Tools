param(
    [string]$sourceOrg, 
    [string]$sourceProjectName, 
    [string]$targetOrg, 
    [string]$targetProjectName, 

    [string]$OutFile, 
    [int]$BatchSize = 50
)
Import-Module Migrate-ADO -Force

function Exec {
    param (
        [scriptblock]$ScriptBlock
    )
    & @ScriptBlock
    if ($lastexitcode -ne 0) {
        exit $lastexitcode
    }
}
function Verify-TeamADGroups($targetProjectName) {
    
    return $false
}

function Get-ServiceConnectionID($sourceOrg) {
    $serviceConnection = Get-Content "$PSScriptRoot\orgs.json" | ConvertFrom-Json -AsHashtable
    $id = $serviceConnection[$sourceOrg]
    if ([string]::IsNullOrEmpty($id)) {
        throw "Service connection for $sourceOrg not found"
    }
    return $id
}

function Migrate-Repos() {

    # todo filter the repos

    $repos = Get-Repos -ProjectName $sourceProjectName -OrgName $sourceOrg -Headers $sourceHeaders
    foreach ($repo in $repos) {
        if($repo.isDisabled){
            "$($repo.Name) is disabled. Skipping..."
        }
        else {
            "Migrating $($repo.Name) ..."
            Migrate-Single-Repo($repo)
        }
        #AddTeamToRepo($targetProjectName-$($repo.Name))
    }
    return $repos
}

function Migrate-Repo($repo) {
    "Migrating repo: $($repo.Name)"
    #Exec { ado2gh lock-ado-repo --ado-org $sourceOrg --ado-team-project $sourceProject --ado-repo $repoName }
    Exec { ado2gh migrate-repo --ado-org $sourceOrg --ado-team-project $sourceProjectName --ado-repo $($repo.Name) --github-org $targetOrg --github-repo "$targetProjectName-$($repo.Name)" }
    #Exec { ado2gh disable-ado-repo --ado-org $sourceOrg --ado-team-project $sourceProjectName --ado-repo $($repo.Name) }
    #Exec { ado2gh configure-autolink --github-org $targetOrg --github-repo "$targetProjectName-$($repo.Name)" --ado-org $sourceOrg --ado-team-project $sourceProject }
    Exec { ado2gh integrate-boards --ado-org $sourceOrg  --ado-team-project $sourceProjectName --github-org $targetOrg --github-repo "$targetProjectName-$($repo.Name)" }
   
    $pipelines = Get-Pipelines -ProjectName $sourceProjectName -OrgName $sourceOrg -Headers $sourceHeaders -RepoId $repo.Id
    foreach ($pipeline in $pipelines) {
        Exec { ado2gh rewire-pipeline --ado-org $sourceOrg  --ado-team-project $sourceProjectName --ado-pipeline $pipeline.Name --github-org $targetOrg --github-repo "$targetProjectName-$($repo.Name)" --service-connection-id $ServiceConnectionId }
    }
}

function Create-GitHubTeams() {
    "Creating teams"
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName" --idp-group "GL-OGH-$targetProjectName" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Admins" --idp-group "GL-OGH-$targetProjectName-Admins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Readers" --idp-group "GL-OGH-$targetProjectName-Readers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Contributors" --idp-group "GL-OGH-$targetProjectName-Contributors" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Managers" --idp-group "GL-OGH-$targetProjectName-Managers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-BuildAdmins" --idp-group "GL-OGH-$targetProjectName-BuildAdmins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-ReleaseApprovers" --idp-group "GL-OGH-$targetProjectName-ReleaseApprovers" }
}

function Add-TeamToRepo($gitHubRepoName){
    "Adding teams to repo: $gitHubRepoName"
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName" --role "read" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-Admins" --role "admin" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-Readers" --role "read" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-Contributors" --role "write" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-Managers" --role "manager" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-BuildAdmins" --role "triage" }
    Exec { ado2gh add-team-to-repo --github-org $targetOrg --github-repo $gitHubRepoName --team "$targetProjectName-ReleaseApprovers" --role "maintain" }

}

### Migrate a project 

if ([string]::IsNullOrEmpty($env:ADO_PAT)) {
    "ADO_PAT not set!"
    return
}
if ([string]::IsNullOrEmpty($env:GH_PAT)) {
    "GH_PAT not set!"
}
$sourceHeaders = New-HTTPHeaders -PersonalAccessToken $env:ADO_PAT
$ServiceConnectionId = Get-ServiceConnectionID($sourceOrg)

Create-GitHubTeams

Migrate-Repos

