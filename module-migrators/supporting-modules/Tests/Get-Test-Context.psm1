Import-Module .\supporting-modules\Migrate-ADO-Common.psm1 -Force

function Get-TestContext {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourcePAT,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetPAT
    )
    return @{
        SourceOrgName      = $SourceOrgName
        SourceProjectName  = $SourceProjectName
        SourceHeaders      = (New-HTTPHeaders -PersonalAccessToken $SourcePAT)

        TargetOrgName      = $TargetOrgName
        TargetProjectName = $TargetProjectName
        TargetHeaders     = (New-HTTPHeaders -PersonalAccessToken $TargetPAT)
    }
}