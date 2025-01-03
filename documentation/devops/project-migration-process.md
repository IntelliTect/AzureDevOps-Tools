# Overview

[Documentation](https://nkdagility.github.io/azure-devops-migration-tools/)
[github](https://github.com/nkdAgility/azure-devops-migration-tools)
[Azure DevOps Site](https://dev.azure.com/nkdagility/migration-tools)

# Project Migration Process

Step by step for migrating a single Project's work items using the [Azure DevOps Migration Tools](https://dev.azure.com/nkdagility/migration-tools) (aka Martin's Tool) to an existing Azure DevOps account

Source is *not* migrated with this tool. See [migrating source code](migrating-project-source-code) for more information.

The migration process copies work items and related data from one project to another.

The tool used expects the target project to be created prior to execution. It will not create the project.

If the source project has custom fields, the target project must have the same fields, or be mapped to existing fields, or the custom data will not be copied. This mapping of custom fields can be defined in migrator-configuration.json

Process customization in newly created Azure DevOps is different than process customization in on premise Team Foundation Server (TFS) installations. 

## Process Overview

1. Fill out project [Survey Spreadsheet]() for the project
2. Determine if an existing Azure DevOps Process Template will work for the project
3. If a new Process Template is Required, create a new process Template
5. Configure and run the migration tool (see project-migration-setup.md) 
6. Validate results
7. User testing and verification

## Notes
- For new projects, peform test migrations to a test organization or project.
- If the source project has work items that link to source code, source code must be migrated prior to creating the links. Additionally, the source path must match so be sure when migrating to leave same structure in place.

## Creating a New Process Template for Migration

1. Copy an existing inherited template used for migration
2. Review any custom fields in the source process. Custom fields will be need to be specially defined on the target account and added to the process prior to migration.
2. Review work items for state changes. Non default states need to either be added or re-mapped to standard states in configuration. 

## Adding Custom Fields to your Azure DevOps Process Template

<tbd> 

## Configure and Run the migration tool

Use an existing configuration template from the source DevOps project, as an existing configuration can be leveraged
Commit the project specific configuration in the event it's needed for reference, or, to use it as a template for similar projects