# Module Imports
Import-Module "./modules/Migrate-ADO-Common.psm1"

# Azure DevOps Migration Environment Variables
# Create a file named env.ps1 in the same directory as this script and copy the content below into it.
# You can use it to set up variables to run functions locally durring development.

# Source Organization and Project
$SourceOrgName = "<SET_YOUR_SOURCE_ORG_NAME>"
$SourceProjectName = "<SET_YOUR_SOURCE_PROJECT_NAME>"
$SourceHeaders = New-HTTPHeaders -PersonalAccessToken "<SET_YOUR_SOURCE_PAT>"

# Target Organization and Project
$TargetOrgName = "<SET_YOUR_TARGET_ORG_NAME>"
$TargetProjectName = "<SET_YOUR_TARGET_PROJECT_NAME>"
$TargetHeaders = New-HTTPHeaders -PersonalAccessToken "<SET_YOUR_TARGET_PAT>"