# Introduction 
Azure DevOps references, tools, how-tos

## DevOps Related Links and References

- [IntelliTect's Kevin Bost on GitKracken](https://www.youtube.com/watch?time_continue=2&v=4UvCz4BQnW0)

- [MS Build Parameters](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild-command-line-reference?view=vs-2015&redirectedfrom=MSDN)

<br />

# Migration Tool Summary
This directory holds pre-written scripts and configuration files that links all of the migration modules under the `supporting-modules` directory as well as the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator) to preform a full DevOps migration.

---
<br />
The AzureDevOps-Tools for project migration consists of a collection of PowerShell Scripts used in conjunction with the [Azure DevOps Migration Tools](https://nkdagility.com/learn/azure-devops-migration-tools/)) to migrate a project from one Azure DevOps Organization to another. The Azure DevOps Migration Tools is used to migrate areas such as Work-Items while other areas of migration not supported by this tool are handled via PowerShell Scripts usind the Azure REST API. 
<br /><br />
Depending on your needs, there is also the option of using the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)) tool for some of your migration needs.
<br /><br />

## .github Directory

This directory is user by GitHub and contains GitHub Action Workflow yml files for executing ADO to ADO project migrations using GitHub Action Workflows.

#### <ins style="font-size:larger;">ado-migration-process-full Workflow</ins> - Ths workflow is used to initiate a full project migration which consists of executing these areas of migration:
 - Areas and Iterations
- Artifacts
- Build Pipelines
- Build Queues & Build Environments
- Dashboards
- Delivery Plans
- Groups
- Policies
- Release Pipelines
- Repositories
- Service Connections
- Service Hooks
- Task Groups
- Teams
- Test Configurations
- Test Plans and Suites
- Test Variables
- Variable Groups
- Wikis
- Work Item Queries
- Work-Items (Including 'Test Cases')


#### <ins style="font-size:larger;">ado-migration-process-org-users</ins> - This Workflow is used to migrate all Users from the Source organization to the Target organization. This is usually done first so that the migration tools can locate and assiciate users to Work-Items and other data points. 

#### <ins style="font-size:larger;">ado-migration-process-partial</ins> - This Workflow is used to execute partial migrations. You would supply the area to be migrated from a dropdown input parameter based on the areas of migration listed above. 

> **Note**
> : Some areas of migration are dependent upon others. Use caution when selecting areas to migrate when dependent areas have not been migrated first. For example, Areas and Iterations should be migrated before migrating work-Items. 

There are two GitHub Action Workflows specifically for migrating Work-Items outside of a full or partial migration. 

#### <ins style="font-size:larger;">ado-migration-process-workitem-backfill-between</ins> - This Workflow will provide a means to migate Work-Items based on a ChangedDate value between two dates. 

#### <ins style="font-size:larger;">ado-migration-process-workitem-backfill</ins> - Use this workflow when you have run a migration but are in the process of testing prior to a Production Cut-Over in order to update Work-Items from the Source that have changed. This Work-Flow allows you to set a number-of-days value. This value tells the migration script to look for items that have changed today back a select number of days prior. 
If the Default value of 0 is left configured then the tool will look for items that have a ChangedDate the day of the Workflow execution date. A value of 1 would locate items the day of and 1 day prior to the execution date etc. 


## Configuration Directory

The configuration directory contains json formatted configuration files for the AzureDevOps-Tools, Azure DevOps Migration Tools and Microsoft VSTS Work Item Migrator tool. 
For more information read more here: : [README - Configuration.md](/configuration/README%20-%20Configuration.md)

## Documentation Directory

Find more information regarding the migration process for Azure DevOps as well as GitHub here.

## Github Tools Directory

If migrating from ADO to GitHub there is a MigrateProject PowerShell script for 

## Helper-Scripts

This directory contains powerShell scripts that are used during the ADO project migration. They are called by other scripts mainly in migration areas where compenents are deleted and re-created in the Target project. 

For more information read more here: : [README - Helper-Scripts.md](/helper-scripts/README - Helper-Scripts.md)

## Images

The images directory contains images that are shown within documentation *.md files. 

# Modules 

This directory contains the many module (*.psm1) files that perform the bulk of ADO project component migrations. 

For more information read more here: : [README - Helper-Scripts.md](/modules/README - Modules.md)





























<br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br />
# Projects.csv
The `Projects.csv` file is where you define a list of source projects and the corresponding target project to migrate to. 
```csv
SourceProject,TargetProject
Source-Project-Name1,Target-Project-Name1
Source-Project-Name2,Target-Project-Name2
Source-Project-Name3,Target-Project-Name3
```
- Lines are separated by new lines, not commas.
- Source project names and target project names are separated by commas.

The first line of the CSV acts as the header, these lines should not be modified (if they are modified you will need to update the header names in the `AllProjects.ps1` script as well.

All following lines define a source project to migrate from and a target project to migrate to.

# Configuration.json
The  `Configuration.json`  file is used to set up file locations for logging, PAT tokens for authentication and other information required for running the  `migration-scripts/AllProjects.ps1`  script.

##### PROPERTIES
| Property Name             | VSTS Only? | Data Type |  Description
|---------------------------|------------|-----------|-------------
| TargetProject             |            | Object    | An object consisting of an OrgName and a PAT
| └─ OrgName                |            | String    | The organization name for the target project
| └─ PAT                    |            | String    | The personal access token you created (or need to create) for the target project    
| SourceProject             |            | Object    | An object consisting of an OrgName and a PAT
| └─ OrgName                |            | String    | The organization name for the source project
| └─ PAT                    |            | String    | The personal access token you created (or need to create) for the source project    
| SavedAzureQuery           | ✔️         | String    | Only required if using the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)  , read more here: ['query' parameter documentation](https://github.com/microsoft/vsts-work-item-migrator/blob/master/WiMigrator/migration-configuration.md#query-the-name-of-the-query-to-use-for-identifying-work-items-to-migrate-note-query-must-be-a-flat)
| ProjectDirectory          |            | String    | The directory where logging, repos and auto-generated configuration files will be placed. Make sure this path is not nested too deeply or file paths may be too long.
| ProjectscCsv              |            | String    | The path of the csv file holding the list of projects you want to migrate. This csv is included in the repo and the path is provided as a relative path, so you should not need to update this setting.
| MsConfigPath              | ✔️         | String    | Only required if using the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)  . This is the configuration file that will be copied and modified for each project. This path is set relatively and the configuration file is provided in the repo so you should not need to update this setting.
| WorkItemMigratorDirectory | ✔️         | String    | Only required if using the  [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)  . This is the directory you cloned the migration tool too. Be sure to include the directory  `WiMigrator`  at the end of the cloned repository path.

----------

**VSTS Only** means that the configuration property is only required if you are using the VSTS work item migrator.

# base-configuration.json ([VSTS only](https://github.com/microsoft/vsts-work-item-migrator))
A pre-configured configuration file used by the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator).
Read more about [base-configuration here](https://github.com/microsoft/vsts-work-item-migrator/blob/master/WiMigrator/migration-configuration.md)

For each project migration defined in the `Projects.csv` the `base-configuration.json` file is copied, modified and saved in that projects directory before a migration is preformed.

# create-manifest.ps1
The `create-manifest.ps1` script creates a new PowerShell distribution manifest file (.psd1) under your `Documents\WindowsPowerShell\Modules` directory. This allows you to use the command `Import-Module Migrate-ADO` to import all of the modules listed under the `$IncludedModules` list in the file.

This script should be run when the repo is first cloned and whenever the `create-manifest.ps1` script is updated.

# AllProjects.ps1
The `AllProjects.ps1` script preforms a full migration of the following DevOps items:
- Area Paths
	- Using the `Start-ADOAreaPathsMigration` cmdlet under `supporting-modules`
- Iteration Paths
	- Using the `StartADOIterationPathsMigration` cmdlet under `supporting-modules`
- Build Queues
	- Using the `Start-ADOBuildQueuesMigration` cmdlet under `supporting-modules`
- Repos
	- Using the `Start-ADORepoMigration` cmdlet under `supporting-modules`
- Work Items
	- Using the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)

The script starts importing the `Projects.csv` and setting a migration run date, which is then used to create a migration directory under the path specified in the `Configuration.json` file.

Each migration defined under `Projects.csv` gets it's own folder where a copy of `base-configuration.json` is created and configured specifically for that migration. All of the migrations are nested under a folder dated with the migration run date set above.

After the project directories are created for each project, the script preforms a migration for each project.


# Migration Notes
- default iteration path is not set a team
- default area path is not set for a team

# Set source to read only
- set repos isDisabled flag to true (manually via UI this pass)
- Move all members of Contributors to Readers. members of groups such as Project Admins, Build Admins, project Collection admins are not affected. Additionally, any specific user assignments will still be valid

