# Overview

[Documentation](https://nkdagility.github.io/azure-devops-migration-tools/)
[github](https://github.com/nkdAgility/azure-devops-migration-tools)
[Azure DevOps Site](https://dev.azure.com/nkdagility/migration-tools)

# Project Migration Process

Step by step for migrating a single Project's work items using the [Azure DevOps Migration Tools](https://dev.azure.com/nkdagility/migration-tools) (aka Martin's Tool) to an existing Azure DevOps account
- Source is *not* migrated with this tool, but is done using a custom powershell module.

See project-migration-setup.md for instractions on setting up this repository withing another GitHub Organization

The migration process copies work items and related data from one project to another.

The tool used expects the target project to be created prior to execution. It will not create the project.

If the source project has custom fields, the target project must have the same fields, or be mapped to existing fields, or the custom data will not be copied. This mapping of custom fields can be defined in migrator-configuration.json

Process customization in newly created Azure DevOps is different than process customization in on premise Team Foundation Server (TFS) installations. 

## Process Overview

1. Fill out project [Survey Spreadsheet]() for the project
2. Determine if an existing Azure DevOps Process Template will work for the project
3. If a new Process Template is Required, create a new process Template (see pre-migration step 1 below)
5. Configure and run the migration tool (see steps below) 
6. Validate results
7. User testing and verification

## Notes
- For new projects, peform test migrations to a test organization or project.
- If the source project has work items that link to source code, source code must be migrated prior to creating the links. Additionally, the source path must match so be sure when migrating to leave same structure in place.

### Pre Migration Steps
1. The target project needs to be created using a process template that mirrors the source process template. If needed the source template can be migrated to the target organization. 
    1. Copy an existing inherited template used for migration
        - We use the Microsoft Process Migrator (https://github.com/microsoft/process-migrator) to migrate the process template by exporting, editing if needing and importing the template in json format. Install this tool using 'npm install process-migrator -g' and fill out the required configuration json file according to the repository documentation.
	        Example command: process-migrator --mode=export --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"
    2. Review any custom fields in the source process template. Custom fields will be need to be specially defined on the target account and added to the process prior to migration.
    2. Review work items for state changes. Non default states need to either be added or re-mapped to standard states in configuration/migrator-configuration.json dirong migration. 
    3. Import the process template
	        Example command: process-migrator --mode=import --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"
    4. (Optional) Commit the project specific process template in the event it's needed for reference, or, to use it as a template for similar projects

2. Users in source organization that are not also in the target organization need to be migrated. This is included in the migration if running a full migration (ado-migration-process-full.yml workflow). Otherwise use Migrate-ADO-Users.psm1 to migrate users.
    
3. Verify that the service account with its token set as the AZURE_DEVOPS_MIGRATION_PAT secret has access to both source and target organizations and has "Basic + Test Plans" licensing access.
  
4. Install any extensions etc used in Source that are not installed already in the target organization. 
  
5. Delete any unneeded/unused Service Connections, Agent Pools, Teams, Groups, Pipelines, Dashboards etc. so that they are not migrated minimizing chances for failures. 
6. Azure RM Service Connection must be created prior to project migration. Service Connection credentials cannot be migrated. 

## Configure and Run the migration tool

1. Verify configuration/migrator-configuration.json is set up correctly regarding area maps and iteration maps. Commit any changes necessary.
2. Execute the desired migration workflow.
    - Execute 'Full ADO Project Migration' workflow to migrate an entire project

## Post Migration Steps
1. Set source to read only: set each repository's isDisabled flag to true (manually via UI)
2. Move all members of Contributors to Readers. Members of groups such as Project Admins, Build Admins, project Collection admins are not affected. Additionally, any specific user assignments will still be valid
3. Wikis get migrated as repositories and need to be re-connected to wiki after migration: https://learn.microsoft.com/en-us/azure/devops/project/wiki/provisioned-vs-published-wiki?view=azure-devops
4. Dashboard Widgets will need to be re-tied to Work-Item queries
5. Set default iteration path for each team as needed. Default iteration path is not set for teams automatically.
6. Set default area path for each team as needed. Default area path is not set for teams automatically.

