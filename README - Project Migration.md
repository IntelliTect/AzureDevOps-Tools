
# Azure DevOps Project Migration

## prerequisites to migration
- The target project needs to be created using a process process template that mirrors the source process template. If needed the source template can be migrated to the target organization. 

    - We use the Microsoft Process Migrator (https://github.com/microsoft/process-migrator) to migrate the process template by exporting, editing if needing and importing the template in json format. 
	 - process-migrator --mode=export --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"
	 - process-migrator --mode=import --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"

- Users in source organization that are not also in the target organization need to be migrated
	- There is a script to perform this user migration.
    
- Token needs to be created that can access both source and target organizations and has "Basic + Test Plans" licensing access.
  
- Install any extensions etc used in Source that are not installed already in the target organization. 
  
- Delete any unneeded/unused Service Connections, Agent Pools, Teams, Groups, Pipelines, Dashboards etc. so that they are not migrated minimizing chances for failures. 

This tool is used for migrating an Azure DevOps (ADO) project to another project location either within the same organization or to another. 
It consists of a set of PowerShell and an external .NET application that handles to migration of various components of the ADO project. 

The PowerShell scripts are comprised of a set of modules and a set of helper scripts that each perform various tasks. 

An external migration tool is also utilized called "Azure DevOps Migration Tools" by Naked Agility, also known as Martin's Tool (https://nkdagility.com/learn/azure-devops-migration-tools/) after the auther Martin Hinshelwood. This tool performs the majority of the ADP migration tasks while the PowerShell Scripts picks up where this migration lacks. 
* Follow the installation instructions here https://nkdagility.com/learn/azure-devops-migration-tools/getting-started/ to install this tool locally. 

## "modules" Directory 
The modules directory contains the PowerShell *.psm1 files each performing a migration of a particular ADO component. 

### The following module files are contained in the modules directory:
```
Migrate-ADO-AreaPaths.psm1
Migrate-ADO-IterationPaths.psm1
Migrate-ADO-Users.psm1
Migrate-ADO-Teams.psm1
Migrate-ADO-Groups.psm1
Migrate-ADO-BuildQueues.psm1
Migrate-ADO-BuildEnvironments.psm1
Migrate-ADO-Repos.psm1
Migrate-ADO-Wikis.psm1
Migrate-ADO-Common.psm1
Migrate-ADO-Pipelines.psm1
Migrate-ADO-Project.psm1
Migrate-ADO-ServiceHooks.psm1
Migrate-ADO-ServiceConnections.psm1
Migrate-ADO-VariableGroups.psm1
Migrate-ADO-Policies.psm1
Migrate-ADO-Dashboards.psm1
Migrate-ADO-BuildDefinitions.psm1
Migrate-ADO-ReleaseDefinitions.psm1
Migrate-ADO-Artifacts.psm1
Migrate-ADO-DeliveryPlans.psm1
ADO-AddCustomField.psm1
Migrate-Packages.psm
```

## "helper-scripts" Directory
This directory contains scripts that were written to provide reports or information that aided in the preperations for project migrations. These PowerShell scripts are not needed for migration but may prove to be useful during the process. 

## "configuration" Directory 
This directory is critical to the process of migrating ADO projects. This directory contains to json formatted process configuration files which will provide the PowerShell scripts with required data to execute on. 
The first file is named configuration.json which will need to be edited and filled out per source project being migrated. In this file you will define inforamtion for the source ADO project and the target ADO project along with the organization(s) and directory file paths. 
Below is what this information looks like:

```
{
    "SourceProject": {
        "Organization": "https://dev.azure.com/[ORGANIZATION]",
        "ProjectName": "[PROJECT_NAME]",
        "OrgName": "[ORGANIZATION-NAME]"
    },
    "TargetProject": {
        "Organization": "https://dev.azure.com/[ORGANIZATION]",
        "ProjectName": "[PROJECT_NAME]",
        "OrgName": "[ORGANIZATION-NAME]"
    },
    "ProjectDirectory": "C:\\DevOps-ADO-migration",
    "WorkItemMigratorDirectory": "C:\\tools\\MigrationTools",
    "DevOpsMigrationToolConfigurationFile": "migrator-configuration.json"
}
```


## Configuration.json
The  `Configuration.json`  file is used to set up file locations for logging, and other information required for running the  `MigrateProject.ps1`  script. This script is the entry point for executing all other PowerShell script migration steps. 

##### PROPERTIES
| Property Name             | Data Type |  Description
|---------------------------|-----------|-------------
| TargetProject             | Object    | An object consisting of an OrgName and a PAT
| └─ Organization           | String    | The organization name for the target project
| └─ ProjectName            | String    | The name of the project being migrated   
| SourceProject             | Object    | An object consisting of an Organization and a PAT
| └─ Organization           | String    | The organization name for the source project
| └─ ProjectName            | String    | The name of the project on the target after migration 
| ProjectDirectory          | String    | The directory where logging, repos and auto-generated configuration files will be placed. Make sure this path is not nested too deeply or file paths may be too long.
| WorkItemMigratorDirectory | String    | This is the directory where the "Azure DevOps Migration Tools" aka Martin's Tool was installed. 
----------
<br /><br />

## Migration Steps PowerShell Scripts
The entire process is initiated through PowerShell Scripts. Use of "Martin's Tool" is done through the PowerShell migration scripts. The entire process is set up in steps which are executed sequentially. 
There is also a script that will esecute the entire process by calling the step scripts in the proper sequence. 

**Note:** The follwoing scripts may require editing depending on project requirements, Work Item counts per ChangedDate period used or other cases where errors occur due to project specifics. 

#### Step_X_Migrate_Org_Level_Users.ps1 - will execute all other steps sequentially
#### Step_1_Migrate_Project.ps1
	Build Queues
	Repos
	Wikis
	Service Connections
#### Step_2_Migrate_Project.ps1
	Area and Iterations
	Teams
	Work Item Querys
	Variable Groups
	Build Pipelines
	Release Pipelines
	Task Groups
#### Step_3_Migrate_Project.ps1
	Work Items (Including 'Test Cases')
	- Work items are batched due to the limitation of the Azure DevOps REST API which is 20,000 items.
	- When doing a full Work-Item migration, items are migrated based on the CreatedDate attribute. 
  	  This is because the query used to search for Work-Items is executed both on the Source and Target
	  projects. Since all items will have a changed date of the date the migration took place, the query 
	  will include all items when run against the Target project. If there are over 20,000 items, this 
	  will results in an error because there is a limit of 20,000 items for the REST API dealing with 
	  work-items.

	In steps where CreatedDate Between
		   0 -  100
		 100 -  200 
		 200 -  300 
		 300 -  400 
		 400 -  500 
		 500 -  600 
		 600 -  700
		 800 -  800
		 800 -  900
		 900 - 1000
		1000 - 1100
		1100 - 1200
		1200 - 1300
		1300 - 1500
		1500 - 3000
		3000 + 

#### Step_4_Migrate_Project.ps1
	This step is executed in two parts 4A and 4B. The first step is performed by "Martin's Tool" and the second half is performed by PowerShell scripts. 
	first:
		Test Configurations
		TestV ariables
		Test PlansAndSuites

	second: 
		Groups
		Service Hooks
		Policies
		Dashboards
		Delivery Plans

#### Step_5_Migrate_Project.ps1
	Artifacts


These steps can each be called one at a time or the Step_0_Migrate_Project.ps1 file can be called to call all of the steps sequentially. 

There is an additional script that is used prior to the actual project migration to migrate organization user accounts from one organization to another named "Step_X_Migrate_Org_Level_Users.ps1". This is needed and requried to be run before the project migration or components such as work items can fail.  


# migrator-configuration.json 
This configuration file is used by the "Azure DevOps Migration Tools" aka Martin's Tool to perform various migration steps. 

**THIS FILE SHOULD NOT BE EDITED MANUALLY**

This file will be edied when calls are made to the MigrateProject.ps1 script. The MigrateProject.ps1 script is either called directly in order to execure select component items or is called by the Step_X_Migrate scripts. 



# create-manifest.ps1
The `create-manifest.ps1` script creates a new PowerShell distribution manifest file (.psd1) under your `Documents\WindowsPowerShell\Modules` directory. This allows you to use the command `Import-Module Migrate-ADO` to import all of the modules listed under the `$IncludedModules` list in the file.

If used, this script should be run when the repo is first cloned and whenever the `create-manifest.ps1` script is updated.

The module files are imported as separate module files and not as a published module. It is not needed to publish the files in the modules directory to execute the project migration. 

# MigrateProject.ps1
The `MigrateProject.ps1` script is the starting point for preforming a full migration of the following DevOps items:

-----------
### Step 1 
- Build Queues 
  - Using the `Start-ADOBuildQueuesMigration` cmdlet under `modules` directory. 
- Build Environments
  - Using the `Start-ADOBuildEnvironmentsMigration` cmdlet under `modules` directory. 
- Repositories
  - Using the `Start-ADORepoMigration` cmdlet under `modules` directory. 
- Wikis 
  - Using the `Start-ADOWikiMigration` cmdlet under `modules` directory. 
- Service Connections 
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
<br />

-----------
### Step 2 
#### via Martin's Tool
- Areas and Iterations
- Teams
- Test Variables 
- Test Configurations 
- Test Plans and Suites 
- Work Item Queries 
- Variable Groups 
- Build Pipelines 
- Release Pipelines 
- Task Groups 
<br />

-----------
### Step 3 
#### via Martin's Tool
- Work Items 
<br />

-----------
### Step 4 
- Groups 
  -  Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
- Service Hooks 
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
- Policies 
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
- Dashboards
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
- Delivery Plans 
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
<br />
-----------
### Step 5
- Artifacts
  - Using the `Start-ADOServiceConnectionsMigration` cmdlet under `modules` directory. 
<br /><br />
-----------

# Migration Notes
- Default iteration path is not set for a team
- Default area path is not set for a team
- Wikis get migrated as repositories and need to be re-connected to wiki after migration 
  - https://learn.microsoft.com/en-us/azure/devops/project/wiki/provisioned-vs-published-wiki?view=azure-devops
- Dashboard Widgets will need to be re-tied to Work-Item queries

# Set source to read only
- set repos isDisabled flag to true (manually via UI this pass)
- Move all members of Contributors to Readers. members of groups such as Project Admins, Build Admins, project Collection admins are not affected. Additionally, any specific user assignments will still be valid

# Prior to Project Migration 
- If migrating from one organization to another,  it is recommended that all User Identities in the Source organization be migrated to the target migration. This allows any ADO components assigned to that user, such as Work Items and Test Plans etc., to be nigrated without error. The user can then be changed after migration. 
- Azure RM Service Connection must be created prior to project migration. Service Connection credentials cannot be migrated. 
- Target organization must have a new enherited Process Template created and a custom field named xxxxx added to all of the Work-Item types. See this documentation for more details: https://nkdagility.com/learn/azure-devops-migration-tools/server-configuration/

