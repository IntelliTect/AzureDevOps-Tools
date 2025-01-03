# Introduction 
This page describe how to set up this repository within your GitHub organization for executing GitHub Actions workflows, as well as the required steps to take prior to and post a project migration.

## Migration Tool Setup

### Set Up Custom Agent that the Migration will Run On
1. Set up a GitHub Actions agent pool
2. Configure virtual machine to run as a GitHub Actions agent within the agent pool
3. Modify the "runs-on" argument to use your agent pool

### How to Set Up this Repository to Run in Another GitHub Organization
1. Clone this repository
2. Add a new remote
3. Push to the new remote
4. Set a GitHub repository secret
    - AZURE_DEVOPS_MIGRATION_PAT: This is the Personal Access Token that the process will use to make calls to the Azure DevOps REST API. The Token name is AZURE_DEVOPS_MIGRATION_PAT and should contain a token that has access to both Source and Target projects and has "Basic + Test Plans" licensing access.
5. Set 3 GitHub repository variables
    - DEVOPSMIGRATIONTOOLCONFIGURATIONFILE: The name of the configuration file for the Azure DevOps Migration Tool (Martin's Tool). The default value is "migrator-configuration.json". 
    - WORKITEMMIGRATORDIRECTORY: The file path on the agent where the GitHub Actions Workflow runner can find the Azure DevOps Migration Tool (Martin's Tool) executable. 
    - ARTIFACTFEEDPACKAGEVERSIONLIMIT: An integer value representing the maximum number of Artifact Feed Package versions to migrate. Default is -1 which tells the migration script to migrate all package versions. 

## Project Migration Prerequsites

### Pre Migration Steps
1. The target project needs to be created using a process template that mirrors the source process template. If needed the source template can be migrated to the target organization. 

    - We use the Microsoft Process Migrator (https://github.com/microsoft/process-migrator) to migrate the process template by exporting, editing if needing and importing the template in json format. 
	 - process-migrator --mode=export --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"
	 - process-migrator --mode=import --config="C:\Users\JohnEvans\Working\Process_Migrate\configuration.json"

2. Users in source organization that are not also in the target organization need to be migrated. This is included in the migration if running a full migration (ado-migration-process-full.yml workflow). Otherwise use Migrate-ADO-Users.psm1 to migrate users.
    
3. Verify that the service account with its token set as the AZURE_DEVOPS_MIGRATION_PAT secret has access to both source and target organizations and has "Basic + Test Plans" licensing access.
  
4. Install any extensions etc used in Source that are not installed already in the target organization. 
  
5. Delete any unneeded/unused Service Connections, Agent Pools, Teams, Groups, Pipelines, Dashboards etc. so that they are not migrated minimizing chances for failures. 
6. Azure RM Service Connection must be created prior to project migration. Service Connection credentials cannot be migrated. 
7. Target organization must have a new inherited Process Template created and any custom fields necessary must be added to all of the Work-Item types. The module ADO-AddCustomField.psm1 can be used to add a custom field to all work item types, or only specfic work item types.

## Post Migration Steps
1. Set source to read only: set each repository's isDisabled flag to true (manually via UI)
2. Move all members of Contributors to Readers. Members of groups such as Project Admins, Build Admins, project Collection admins are not affected. Additionally, any specific user assignments will still be valid
3. Wikis get migrated as repositories and need to be re-connected to wiki after migration: https://learn.microsoft.com/en-us/azure/devops/project/wiki/provisioned-vs-published-wiki?view=azure-devops
4. Dashboard Widgets will need to be re-tied to Work-Item queries
5. Set default iteration path for each team as needed. Default iteration path is not set for teams automatically.
6. Set default area path for each team as needed. Default area path is not set for teams automatically.


