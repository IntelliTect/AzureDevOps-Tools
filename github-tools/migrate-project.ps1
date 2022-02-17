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

function Create-GHTeams() {

#    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName" --idp-group "GL-OGH-$targetProjectName" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Admins" --idp-group "GL-OGH-$targetProjectName-Admins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Readers" --idp-group "GL-OGH-$targetProjectName-Readers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Contributors" --idp-group "GL-OGH-$targetProjectName-Contributors" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-Managers" --idp-group "GL-OGH-$targetProjectName-Managers" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-BuildAdmins" --idp-group "GL-OGH-$targetProjectName-BuildAdmins" }
    Exec { ado2gh create-team --github-org $targetOrg --team-name "$targetProjectName-ReleaseApprovers" --idp-group "GL-OGH-$targetProjectName-ReleaseApprovers" }

}


