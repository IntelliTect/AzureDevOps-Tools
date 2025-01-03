# Migration through GitHub Action Workflows
There are three GitHub Action Workflows to for ADO project migration using the Project Migration scripts outlined in the "README - Project Migration.md" file. 

These Workflows are outlined below:

## "Run ADO Organization User Migration"
Use this Action Workflow in order to migrate Azure DevOps organization level users from a Source organization to a Target organization.
Fill in the input boxes with the Source and target information and run the workflow. 

***Please Note:*** <br/>
On all of the workflows there is a "Whatif" checkbox input option which allows you to run a Dry Run to test connectivity to the powershell scripts.
No data will actually be migrated if the WhatIf checkbox is checked.

![Alt text](.images/user-migration-workflow.png)

## "Run Full ADO Project Migration"
The Full Run Action Workflow is used to process a FULL ADO project to Project migration. This will perform all of the migrations scripts described in the "README - Project Migration.md" file.
The process is run in consecutive steps which provide the correct sequence for dependencies. 

![Alt text](.images/user-migration-workflow.png)

## "Run Partial ADO Project Migration"

The last Action Workflow is the Partial migration. Use this to re-run sections of a full migration. This workflow will be used to do delta-backflow migrations in areas such as work-items and also for testing and correcting any migration issues. Each of the areas of migration are contained in a drop-down selection box labeled "Migration Selection". Use this input option to select the area that you would like to migrate separately. 

![Alt text](.images/partial-migration-workflow.png)

Migration Step Execution Order 
--------------------
Teams
Area And Iterations
Groups
Test Variables
Test Configurations
Test Plans And Suites
Work Item Queries
Shared Queries
Repos
Wikis
Task Groups
Variable Groups
Service Connections
Build Queues
Build Pipelines
Release Pipelines
Service Hooks
Policies
Dashboards
Custom Field For Work Item Migration
WorkItems