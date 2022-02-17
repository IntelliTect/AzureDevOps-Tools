param(
    [string]$sourceOrg, 
    [string]$sourceProjectName, 
    [string]$targetOrg, 
    [string]$targetProjectName, 

    [string]$OutFile, 
    [int]$BatchSize = 50
)

if (string.IsEmpty($env:ADO_PAT)) {
    "ADO_PAT not set!"
    return
}
if (string.Empty($env:GH_PAT)) {
    "GH_PAT not set!"
}

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

function Get-ServiceConnection() {
    #todo get the service connection for this org
    # return it
}

function Migrate-Repos() {
    #todo get repos
    # for each $repo
}

function Migrate-Single-Repo($repoName) {
    Exec { ./ado2gh lock-ado-repo --ado-org "intellitect-samples" --ado-team-project "AzureDevOpsDemo2018" --ado-repo "AzureDevOpsDemo2018.Utilities" }
    Exec { ./ado2gh migrate-repo --ado-org $sourceOrg --ado-team-project $sourceProject --ado-repo $repoName --github-org $targetOrg --github-repo "$targetProjectName-$($repo.Name)" }
    Exec { ./ado2gh configure-autolink --github-org "Intellitect-Samples" --github-repo "AzureDevOpsDemo2018-AzureDevOpsDemo2018.Utilities" --ado-org "intellitect-samples" --ado-team-project "AzureDevOpsDemo2018" }
    AddTeamsToRepo($repoName)
    Exec { ./ado2gh integrate-boards --ado-org "intellitect-samples" --ado-team-project "AzureDevOpsDemo2018" --github-org "Intellitect-Samples" --github-repo "AzureDevOpsDemo2018-AzureDevOpsDemo2018.Utilities" }
    Exec { ./ado2gh rewire-pipeline --ado-org "intellitect-samples" --ado-team-project "AzureDevOpsDemo2018" --ado-pipeline "Utilities - CI" --github-org "Intellitect-Samples" --github-repo "AzureDevOpsDemo2018-AzureDevOpsDemo2018.Utilities" --service-connection-id "f14ae16a-0d41-48b7-934c-4a4e30be71e1" }
}

function Create-GHTeams() {

    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName" --idp-group "GL-OGH-$targetProjectName" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Admins" --idp-group "GL-OGH-$targetProjectName-Admins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Readers" --idp-group "GL-OGH-$targetProjectName-Readers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Contributors" --idp-group "GL-OGH-$targetProjectName-Contributors" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Managers" --idp-group "GL-OGH-$targetProjectName-Managers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-BuildAdmins" --idp-group "GL-OGH-$targetProjectName-BuildAdmins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-ReleaseApprovers" --idp-group "GL-OGH-$targetProjectName-ReleaseApprovers" }

}


