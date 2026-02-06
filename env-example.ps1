# Module Imports
Import-Module "./modules/Migrate-ADO-Common.psm1"

# Azure DevOps Migration Environment Variables
# Create a file named env.ps1 in the same directory as this script and copy the content below into it.
# You can use it to set up variables to run functions locally durring development.

# Source Organization and Project
Set-Variable -Name "SourceOrgName" -Value "<SourceOrgName>" -Visibility Public -Force
Set-Variable -Name "SourceProjectName" -Value "<SourceProjectName>" -Visibility Public -Force
Set-Variable -Name "SourcePAT" -Value "<SourcePAT>" -Visibility Public -Force
Set-Variable -Name "SourceHeaders" -Value (New-HTTPHeaders -PersonalAccessToken $SourcePAT) -Visibility Public -Force

# Target Organization and Project
Set-Variable -Name "TargetOrgName" -Value "<TargetOrgName>" -Visibility Public -Force
Set-Variable -Name "TargetProjectName" -Value "<TargetProjectName>" -Visibility Public -Force
Set-Variable -Name "TargetPAT" -Value "<TargetPAT>" -Visibility Public -Force
Set-Variable -Name "TargetHeaders" -Value (New-HTTPHeaders -PersonalAccessToken $TargetPAT) -Visibility Public -Forc