# Tool Scripts 

This directory contains helpful PowerShell scripts that can be used to perform specific actions outside of an ADO project migration or in aiding in the testing, validating and troubleshooting during an ADO project migration. 


## Files

### Clone-All-Project-Repos.ps1

### Create-Manifest.ps1: 
The `Create-Manifest.ps1` script creates a new PowerShell distribution manifest file (.psd1) under your `\Modules` directory. This allows you to use the command `Import-Module Migrate-ADO` to import all of the modules listed under the `$IncludedModules` list in the Create-Manifest.ps1 file.


### DeleteDashboards.ps1: 
The `DeleteDashboards.ps1` script can be used to remove all current dashboards in the Target project prior to running an ADO project migration for a clean Dhasboard migration. 


### DeleteGroups.ps1:
Used to delete all ADO Security Groups in order start with a freash re-migration of all ADO Security Groups.

### DeleteServiceConnections.ps1:
Service connections can be migrated with the exception of the credentials configured for them. Many times external processes are used to generate service connections. This script can be used to remove all of the service connection post migration so that new connections can be created. 

### Generate_Artifact_Feed_Package_Version_Data.ps1:
The `Generate_Artifact_Feed_Package_Version_Data.ps1` script is a helpful script when dealing with migrating Artifact Feed packages and the many versions that tend to collect. It generates a data repost lsting all of the packages and their verions for your Artifact feeds. 

### GetCurrentUserInfo.ps1:
This script will generate a data report containing user data that can be evaluated prior to and/or after a user migration.

### GetItemsNotMigrated.ps1:
The migration of ADO work items can be a tedious process when the project being migrated contains thousands if not hundres of thousands of items. This can make it difficult to identify problems when migraitng work items. The `GetItemsNotMigrated.ps1` script will generate a report of all work items that are in the Source project that does not have a corresponding migrated work item in the Target project. 

### GetMigratedItemCounts.ps1:
This script is used in conjunction with the `GetItemsNotMigrated.ps1` script above to assist in identifying any issues during a work item migration. 

### GetServiceConnectionsLastUsed.ps1:
When migrating many service connections sometimes during a migration you want to not migrate items that are no longer used nor needed. This script will provide a list of the service connections present and the last time they were accessed so that you can make a determination to remove the unused service connections prior to doing a migration. 

### IdentifyPlansAndSuitesForUnknowUsers.ps1:
The `IdentifyPlansAndSuitesForUnknowUsers.ps1` script can be used to identify Test Plans, test Suite, and Test-Cases whos owner is not a user identity in the organization. 

### IdentifySuitesAndCasesForTestPlans.ps1:
This script is useful for identifying all of the Test Cases that a Test Plan contains. 

### Set-Readonly.ps1:
Set source to read only
- set repos isDisabled flag to true (manually via UI this pass)
- Move all members of Contributors to Readers. members of groups such as Project Admins, Build Admins, project Collection admins are not affected. Additionally, any specific user assignments will still be valid.

### ValidateBuildEnvironments.ps1:
The `ValidateBuildEnvironments.ps1` script is used to assist in validating build environment migration results. 

### ValidateBuildGroupsAndUsers.ps1:
The `ValidateBuildGroupsAndUsers.ps1` script is used to assist in validating build groups and users migration results. 

### VerifyFieldsForOrganizationProject.ps1, VerifyFieldsForWorkItemInProcess.ps1:
The `VerifyFieldsForOrganizationProject.ps1` and  `VerifyFieldsForWorkItemInProcess.ps1` scripts are used to validate custom fields that are present for process templates prior to doing a project migration. In order to successfully migrate a project's work items, the process templates of the Source and Target must match fields.  





