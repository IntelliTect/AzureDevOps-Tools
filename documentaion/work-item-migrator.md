# Work Item Project Migration

Using the [Microsoft Work Item Migration Tool](https://github.com/microsoft/vsts-work-item-migrator)

## Pre-requisites
- Requires .NET Core to run
- Download the latest code from the repo to get started

## Process

Create a configuration json for each of the target projects
The configuration is created from the sample provided by the project
Unless defaults are provided, Areas and Iterations must match in order for an item to be migrated
Rather than attempting to map these, we have elected to only use a single Area Path per project, and, to assign all work to the project's default Iteration Path

## Configure Area Path and Iteration Path 
An Area Path has already been created for each project have already been created.

A default iteration path that is equal to "Applications\<project name>" should be configured for each project prior to migrating work items for that project.

## Configuring the migration

Key settings include:
- PATs for the Source and Target project
- Source and target accounts
- source and target project names
- Shared Query that includes all work items to be included in the migration

The same PAT and source and target accounts will be used for each migation
The target project name, Applications, will also be the saeme for each migration

## Step by step
1. Copy a new json file from the default
2. Set the source project name in the json
3. Create a query (named "allitems") in the source project, be sure to save in Shared Queries
4. Set the the area path as follows:  "default-area-path": "Applications\\<project naame>",
5. Set the iteration path as follows: "default-iteration-path": "contoso-project\\<project name>",
6. run a migration valiation using ```dotnet run --validate <projectname>.json```
7. Run the migration using ```dotnet run --migrate <projectname>.json```


