# Introduction 
This page describe how to set up this repository within your GitHub organization for executing GitHub Actions workflows.

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
