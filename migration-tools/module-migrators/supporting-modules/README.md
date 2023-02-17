# Supporting Modules Directory
This directory holds all of the migration logic provided by this repo. The following operations and their corresponding module files are what is currently supported:

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
