# Migration Scripts Directory
This directory holds pre-written scripts and configuration files that links all of the migration modules under the `supporting-modules` directory as well as the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator) to preform a full DevOps migration.

---

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