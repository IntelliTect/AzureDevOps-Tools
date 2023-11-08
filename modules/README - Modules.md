# Supporting Modules Directory
This directory holds all of the migration logic provided by this repo. The following operations and their corresponding module files are what is currently supported:

---
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
Migrate-Packages.psm1
```


### Migrate Azure DevOps Area Paths
##### MODULE FILE: `Migrate-ADO-AreaPaths.psm1` 
This module file provides the following functions: 
- `Start-ADOAreaPathsMigration`
	- Migrates area paths from one DevOps project to another. Relies on all other functions provided in this file.
- `ConvertTo-AreaPathObject`
	- Flattens the area path objects returned from the DevOps REST API call and converts them to a custom PowerShell `ADO_AreaPath` object.
- `Get-AreaPaths`
	- Returns all of the area paths for a given project as a list of custom PowerShell  `ADO_AreaPath` objects.
- `Push-AreaPaths`
	- Pushes a list of area paths in the form of an array of custom PowerShell `ADO_AreaPath` objects to a given project.
---

### Migrate Azure DevOps Iteration Paths
##### MODULE FILE: `Migrate-ADO-IterationPaths.psm1` 
This module file provides the following functions: 
- `Start-ADOIterationPathsMigration`
	- Migrates iteration paths from one DevOps project to another. Relies on all other functions provided in this file.
- `ConvertTo-IterationPathObject`
	- Flattens the iteration path objects returned from the DevOps REST API call and converts them to a custom PowerShell `ADO_IterationPath` object.
- `Get-AreaPaths`
	- Returns all of the iteration paths for a given project as a list of custom PowerShell  `ADO_IterationPath` objects.
- `Push-AreaPaths`
	- Pushes a list of iteration paths in the form of an array of custom PowerShell `ADO_IterationPath` objects to a given project.
---

### Migrate Azure DevOps Users
##### MODULE FILE: `Migrate-ADO-Users.psm1` 
This module file provides the following functions (at the ORG level, not project specific): 
- `Start-ADOUserMigration`
	- Migrates users from one DevOps orginization to another. Relies on all other functions provided in this file.
- `Push-ADOUsers`
	- Loops through a list of custom PowerShell `ADO_User` objects and compares for duplicates. If the user is not a duplicate they will be added to the target org with the `Add-ADOUser` function.
- `Add-ADOUser`
	- Adds a user by their user principal name to a DevOps orginization and updates their license using the Azure DevOps CLI
- `Get-ADOUsers`
	- Gets all users from a specific org and returns them as custom PowerShell `ADO_User` objects.
---

### Migrate Azure DevOps Teams
##### MODULE FILE: `Migrate-ADO-Teams.psm1` 
This module file provides the following functions: 
- `Start-ADOTeamsMigration`
	- Migrates EMPTY teams from one DevOps orginization to another. Relies on all other functions provided in this file.
- `Get-ADOProjectTeams`
	- Gets a list of custom PowerShell `ADO_Team` objects for a specific org and project or a specific `ADO_Team` project if a team name is specified to filter by.
- `Push-ADOTeams`
	- Loops through a list of custom PowerShell `ADO_Team` objects and compares for duplicates. If the team is not a duplicate it will be added on the target.
- `New-ADOTeam`
	- Creates a new, empty team, in the specified org and project. The creation of a new team also triggers the creation of a new group.
---

### Migrate Azure DevOps Teams
##### MODULE FILE: `Migrate-ADO-Groups.psm1` 
This module file provides the following functions: 
- `Start-ADOGroupsMigration`
	- Migrates groups and their members from one DevOps orginization to another. Relies on all other functions provided in this file.
- `Get-ADOGroups`
	- Gets a list of custom PowerShell `ADO_Group` objects for the specified org and project.
- `Get-ADOGroupMembers`
	- Gets a list of user group members and group group members and returns a hashtable of custom PowerShell `ADO_Group` and `ADO_GroupMember` objects.
- `Push-ADOGroups`
	- Loops through each source group and creates a new empty target group with `New-ADOGroup`. After all groups are created it re-loops through all of the newly created groups and pushes group members to each group using `Push-GroupMembers`.
- `New-ADOGroup`
	- Creates a new, empty, ADO group and returns a custom PowerShell `ADO_Group` object
- `Push-GroupMembers`
	- Adds user members and group members of a specified, existing, group.
---

### Migrate Azure DevOps Build Queues
##### MODULE FILE: `Migrate-ADO-BuildQueues.psm1` 
This module file provides the following functions: 
- `Start-ADOBuildQueuesMigration`
	- Migrates build queues from one DevOps project to another. Relies on all other functions provided in this file.
- `Get-BuildQueues`
	- Returns all of the build queues for a given project as a list of custom PowerShell `ADO_BuildQueue` objects.
- `Push-BuildQueues`
	- Checks if any of the provided build queues already exist & pushes the build queues to DevOps using the `New-BuildQueue` function. Requires a list of custom PowerShell `ADO_BuildQueue` objects.
- `New-BuildQueue`
	- Creates a new build queue in DevOps with the properties provided by a custom PowerShell `ADO_BuildQueue` object passed to it.
---

### Migrate Azure DevOps Build Enironments
##### MODULE FILE: `Migrate-ADO-BuildEnvironments.psm1`

This module file provides the following functions: 
- `Start-ADOBuildEnvironmentsMigration`
  - Migrates Build Environments from one DevOps project to another. Relies on all of the other functions provided in this file. 
- `Get-BuildEnvironments`
  - Gets a list of all of the Build Environments for a given project.
- `Get-BuildEnvironmentRoleAssignments`
  - Get a list of Role Assignments associated with a given build environment.
- `Get-IdentityInfo`
  - Gets information for a given Identity by it ID. 
- `Set-BuildEnvironmentRoleAssignment`
  - Set a new role assignment for a given build environment.
- `Get-BuildEnvironmentPipelinePermissions`
  - Get build pipeline permissions for a goven build environment.
- `Set-BuildEnvironmentPipelinePermissions`
  - Sets a new build evnironment pipeline permission.
- `New-BuildEnvironment`
  - Creates a new build environment. 
---

### Migrate Azure DevOps Repos
##### MODULE FILE: `Migrate-ADO-Repos.psm1`
This module file provides the following functions:
- `Start-ADORepoMigration`
	- Migrates repos from one DevOps project to another. Relies on all other functions provided in this file.
- `Get-Repos`
	- Gets a list of repos from DevOps for a given project
- `Copy-Repos`
	- Clones a list of repos from DevOps to the users local machine using a provided path
- `Push-Repos`
	- Loops through a list of provided repo objects, creates a new empty repository for each repo using `New-GitRepository` and uses git to push the downloaded repos to DevOps. Requires `Copy-Repos` to be run first.
- `New-GitRepository`
	- Creates a new empty git repo in Azure Devops
	- 
---

### Migrate Azure DevOps Wikis
##### MODULE FILE: `Migrate-ADO-Wikis.psm1`

This module file provides the following functions:
- `Start-ADOWikiMigration`
  - Migrate Wiki data from one project to another. It utilizes the `Get-Wikis` and `Get-Wiki` functions also contained in this file. 
- `Get-Wikis`
  - Gets a list of Wikis that will be used in migrating them to a target ADO project. 
- `Get-Wiki`
  - Get further informatiob about a specific Wiki.
---

### Common Files Shared Between the Migration Modules
##### MODULE FILE: `Migrate-ADO-Common.psm1`
This module file provides the following functions:
- `New-HTTPHeaders`
	- Generates basic auth headers using a provided personal access token.
- `Get-ADOProjects`
	- Gets either a specific Azure DevOps project by name or all projects for a given org
- `Write-Log`
	- Handles writing messages to the console and calling `Write-LogAsync` to log those messages to a file path set via an environment variable
- `Write-LogAsync`
	- Handles writing messages to log files to a given path.
- `ConvertTo-Object`
- `ConvertTo-HashTable`
- `Get-ProjectFolderPath`
	- Returns the formatted folder path based on the migration start date and target/source projects
- `Set-ProjectFolders`
	- Creates a directory of projects to store logs and downloaded repo files during the migration
---

### Migrate Azure Devops Pipelines
##### MODULE FILE: `Migrate-ADO-Pipelines.psm1`

This module file provides the following functions:
- `Get-Pipelines`
  - Gets a list of pipeline build definitions.

> **_NOTE:_** Pipeline migration is handled by the Azure DevOps Migration Tools (Martin's Tool)
---

### Migrate ADO Project
##### MODULE FILE: `Migrate-ADO-Project.psm1`

This module file provides the following functions:
- `Start-ADOProjectMigration`
  - This Function is the main entry point for migrations of all component areas of a project handled by the modules within this directory. This function can be called and in turn will call the other various module functions. 

---
### Migrate Azure Devops Service Hooks
##### MODULE FILE: `Migrate-ADO-ServiceHooks.psm1`

This module file provides the following functions:
- `Start-ADOServiceHooksMigration`
  - Migrates Service hooks from one ADO project to another. This function calls the `Get-ServiceHooks` and `New-ServiceHook1` functions. 
- `Get-ServiceHooks`
  - Gets a list of service hooks for a given ADO project. 
- `New-ServiceHook`
  - Creates a new service hook within a given ADO project. 

---
### Migrate Azure Devops Service Connection
##### MODULE FILE: `Migrate-ADO-ServiceConnections.psm1`

This module file provides the following functions:
- `Start-ADOServiceConnectionsMigration`
  - Migrates Service Connections from one ADO project to another ADO project. Relies on all other functions provided in this file.
- `Get-ServiceEndpoints`
  - Gets a list of all service connection service end-points defined within an ADO project. 
- `New-ServiceEndpoint$ServiceEndpoint`
  - Creates a new service connection service end-point within a given ADO project. 

> **_NOTE:_** Service Principal credentials or name/password credentials for service connections cannot be created. All migrated service connections will need to be manually updated or replaced after migration.

---
### Migrate Azure Devops variable Groups 
##### MODULE FILE: `Migrate-ADO-VariableGroups.psm1`

This module file provides the following functions:
- `Start-ADOVariableGroupsMigration`
  - Migrates Pipeline variable Groups from one ADO project to another. Relies on all other function contained in this file. 
- `Get-VariableGroups`
  - Gets a list of all defined variable groups for a given ADO project. 
- `Get-VariableGroup `
  - Gets information on a specific variable group by its ID.
- `New-VariableGroup`
  - Creates a new pipeline variable group for a given ADO project. 

> **_NOTE:_** Migration of Pipeline Variable Groups are also handled by the Azure DevOps Migration Tools (Martin's Tool). 

---
### Migrate Azure Devops Policies
##### MODULE FILE: `Migrate-ADO-Policies.psm1`

This module file provides the following functions:
- `Start-ADOPoliciesMigration`
  - Migrates repository and branch policies from one ADO project to another. This function relies on some of the other functions defined within this file. 
- `Get-Policies`
  - Gets a list of all of the repository and branch policies defined for a given ADO project. 
- `Get-UserIdentity`
  - Gets a specified user idenity dataset defined in a given projects organization by its identity ID.
- `Get-UserByDescriptor`
  - Get data for a user identoty defined in a given project's organization by its descriptor value. 
- `New-Policy`
  - Creates a new repo/branch policy for a given ADO project. 
- `Edit-Policy`
  - Edits or updates an existing and specified repo/branch policy.

---
### Migrate Azure Devops Dashboards
##### MODULE FILE: `Migrate-ADO-Dashboards.psm1`

This module file provides the following functions:
- `Start-ADODashboardsMigration`
  - Migrates Dashboards from one ADO project to another. Relies on all other function contained within this file. 
- `Get-Dashboards`
  - Gets a list of dashboard datasets for a given ADO project.
- `Get-Dashboard`
  - Gets a specific dashboard's data information for a given ADO project by a specified dashboard ID value. 
- `New-Dashboard`
  - Creates a new dashboard for a given ADO project. 
- `Edit-Dashboard`
  - Edit an existing dasboard defined for a goven ADO project.
- `Get-Teams`
  - Gets a list of Teams for a given ADO organization and project. This is used to get team dashboards vs project level dashboards.

---
### Migrate Azure Devops Build Definitions
##### MODULE FILE: `Migrate-ADO-BuildDefinitions.psm1`

This module file provides the following functions:
- `Start-ADOBuildDefinitionsMigration`

> **_NOTE:_** This script has not been fully implemented. Build and Release Pipeline migration is handled by the Azure DevOps Migration Tools (Martin's Tool)

---
### Migrate Azure Devops Release Definitions
##### MODULE FILE: `Migrate-ADO-ReleaseDefinitions.psm1`

This module file provides the following functions:
- `Start-ADOReleaseDefinitionsMigration`
  
> **_NOTE:_** This script has not been fully implemented. Build and Release Pipeline migration is handled by the Azure DevOps Migration Tools (Martin's Tool)

---
### Migrate Azure Devops Artifacts
##### MODULE FILE: `Migrate-ADO-Artifacts.psm1`

This module file provides the following functions:
- `Start-ADOArtifactsMigration`
  - Migrates artifact feeds and their defined package versions from one ADO project to another. Replies on all other functions contained with this file.
- `Get-OrganizationId`
  - get the ID for a goven project name within a given organization. 
- `Get-Feeds`
  - Gets a list of artifact feeds for a given ADO project. 
- `Get-Feed`
  - Gets a specific artifact feed for a given ADO project by its feed ID.
- `Update-Feed`
  - Updates a given arifact feed within a given ADO project by its ID.
- `New-ADOFeed`
  - Creates a new artifact feed for a given ADO project.
- `Get-Views`
  - Get a list of defined views for a given artifact feed within a given ADO project. 
- `Update-View`
  - Updates an existing artifact feed's view.
- `Get-Packages`
  - Gets a list of all package versions for a given artifact feed.
- `Start-Command`
  - Executes an executable process by creating a new .NET System.Diagnostics.Process object and starting it. This is used by the artifact migration to call the nuget executable to perform various actions during the migration process.  

---
### Migrate Azure Devops Delivery Plans
##### MODULE FILE: `Migrate-ADO-DeliveryPlans.psm1`

This module file provides the following functions:
- `Start-ADODeliveryPlansMigration`
  - Migrates Delivery Plans defined for a given ADO project. relies on all other functions defined within this file.
- `Get-DeliveryPlans`
  - Gets a list of all delivery plans for a given ADO project. 
- `Get-DeliveryPlan`
  - Gets a spcific delivery plan for a given ADO project by its delivery plan ID.
- `New-DeliveryPlan`
  - Creates a new delivery plan for a given ADO project.

---
### Project Process template Add Custom Field
##### MODULE FILE: `ADO-AddCustomField.psm1`

This module file provides the following functions:
- `Start-ADO_AddCustomField`
  - Begins the process of adding a new custom field for a given organization/project so that it can be added to all work item types for the project's process template. 
  - This function relies on all of the other functins defined in this file. 
- `Get-ProcessWorkItemTypes`
  - Gets a list of all work item types defined for the organizational process template that a given ADO project is using. 
- `Add-CustomField`
  - Adds a custom field to a spcific work item type for the projects process template. 
- `ConvertTo-WorkItemTypeObject`
  - Converts a given REST API dataset to a custom defined PowerShell `WorkItemType` object.
- `Get-Processes`
  - Gets a list of all of the process templates defined for a given organization.
- `Get-ProcessesDefinitions`
  - Gets the process definitions list for a given organization and specified process template ID.
- `Get-CustomfieldsList`
  - Gets a list of of all defined custom fields for a specified process template. 
- `New-Customfield`
  - Creates a new custom field for a specified process template.

---
### Migrate Artifact Feed Packages
##### MODULE FILE: `Migrate-Packages.psm1`

This module file contains the following functions:
- `Get-ContentUrls`
- `Get-V3SearchBaseURL`
- `Get-V3FlatBaseURL`
- `Get-RegistrationBase`
- `Get-Index`
- `Get-Packages`
- `Read-CatalogUrl`
- `Read-CatalogEntry`
- `Start-MigrationSingleThreaded`
- `Start-Migration`
- `Out-Result`
- `Out-Results`
- `Get-MissingVersions`
- `Start-Command`
- `Update-NuGetSource`

This module file is based on Microsoft's AzureArtifactsPackageMigration PowerShell module for migrating Azure artifact feed packages.
The main Function for this module is the Move-MyGetNuGetPackages function which is exported by this module file.

For more information about migrating artifact feed packages using Microsoft's migration tools, read more here:<br />
 [Azure Aritfact Migration Tool](https://github.com/microsoft/azure-artifacts-migration)<br />
[Microsoft Learn: Migrating Azure DevOps Feed Packages](https://learn.microsoft.com/en-us/azure/devops/artifacts/tutorials/migrate-packages?view=azure-devops&tabs=Windows)
---

