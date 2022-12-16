Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName
)

#-sourcePat $sourcePat -sourceOrg $sourceOrg -sourceProjectName "SampleCRM" -targetPat $targetPat

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "---------------------------"
Write-Log -msg "-- Migrate Team Members  --"
Write-Log -msg "---------------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$teams = Get-Teams -project $SourceProjectName -org $SourceOrg -headers $sourceHeaders

Class TeamMember {
    [string]$teamName
    [string]$teamId
    [string]$userId
    [string]$userName
    [string]$userDescriptor
    [bool]$isTeamAdmin
}
$teamMembers = @()

# $teamMembers = @()

$teams | ForEach-Object {
    $teamName = $_.name
    $teamId = $_.id
    Write-Host "Team: $teamName"

    $result = Get-TeamMembers -team $teamName -project $SourceProjectName -org $SourceOrg -pat $sourcePat
    if ($result) {
        $result.value | foreach-object {
            $teamMember = [TeamMember]@{
                teamName = $teamName; 
                teamId = $teamId; 
                userId = $_.identity.id; 
                userName = $_.identity.uniqueName
                isTeamAdmin = $_.isTeamAdmin
            }
            $teamMembers += $teamMember
        }    
    }
}

# for now just return team members
return $teamMembers

#todo lookup AD ID for Azure Identity for each unique team member
#todo check user provisioning (basic, VS, ...)
#todo add unique team member to the target
#todo add members to teams




