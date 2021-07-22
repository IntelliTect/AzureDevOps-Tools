
  

# Introduction

  

DevOps Migrator modules and driver script to migrate multiple projects in bulk. Read through the documentation below to learn how to get started with your first migration!

  

The modules provided support the following migration options:
- Migrate Users (On the ORG level)

- Migrate Teams (On the project level)

- Migrate Team Members (On the project level)

- Migrate Area Paths

- Migrate Iterations

- Migrate Repos

- Migrate Build Queues

  

Migrating work items is not supported in this tool, see dependencies for additional options.

  

# Dependencies

- You will need the [Microsoft VSTS Work Item Migrator](https://github.com/microsoft/vsts-work-item-migrator) or something comparable to migrate work items.

- PowerShell 5.1.0 or later

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
	- [Azure CLI DevOps Extension](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)

  

# Getting Started

There is some simple set up that needs to be done before you can run any of the migration modules. Included in the repo are two directories...

- 📂 Migration-Scripts

- 📂 Supporting-Modules

  

The `migration-scripts` directory holds scripts, configuration files and a list of projects in the form of a `.csv`. The `supporting-modules` directory holds `psm1` module files that do the heavy lifting in the migration. Theoretically, a migration can be run completely from the command-line, the items nested under the `migration-scripts` directory are not technically required, but rather act as a centralized place to run repeat migrations in bulk.

  

---

### STEP 1: Installing the modules manifest

The first step to running a migration will be installing the modules manifest. There is also a pre-defined script provided under the `migration-scripts` directory that will automatically do this for you.

##### STEPS:

- Open the PowerShell script `migration-scripts/create-manifest.ps1`

- Run the script

- The script will create a manifest of all the required modules in your `WindowsPowerShell/Modules` directory. This will allow you to use `Import-Module` to load all of the required modules.

  

You should only have to run this script the first time cloning this repo or when the `migration-scripts/create-manifest.ps1` file is changed. Read more about the [`create-manifest.ps1` script here](migration-scripts/README.md#create-manifest.ps1)

  

---

### All steps listed below are only required if you plan on using the `migration-scripts/AllProjects.ps1` script, which is recommended.

---

  

### STEP 2: Clone the Microsoft VSTS Work Item Migrator

The modules provided in this repo do not handle any kind of work item migration, so if you would like to migrate work items I recommend the tool written by Microsoft, but you are not limited to this tool, if you choose to go another route just edit the `migration-scripts/AllProjects.ps1` file to use whatever tool you go with.

##### STEPS:

- Navigate to the [Microsoft VSTS Work Item Migrator](https://github.com/microsoft/vsts-work-item-migrator) GitHub and [clone the repo](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository-from-github/cloning-a-repository) to your local machine.

---

### STEP 3: Configuring the Configuration.json file

The `Configuration.json` file is used to set up file locations for logging, PAT tokens for authentication and other information required for running the `migration-scripts/AllProjects.ps1` script.

##### STEPS

- Open the file `migration-scripts/Configuration.json` and fill out the required fields...
	- Read more about the [configuration fields here](migration-scripts/README.md#configuration.json)

---

### STEP 4: Defining projects to migrate in the Projects.csv file

##### STEPS

- Open the file `migration-scripts/Projects.csv` and add the list of source projects to target projects you wish to migrate.
- Read more about the [Projects.csv file here](migration-scripts/README.md#Projects.csv)

You should now be able to run a migration.

  

# Running a Migration With The `AllProjects.ps1` Script

After going through the above steps, navigate to `migration-scripts/AllProjects.ps1` and either invoke the script via the command line or run it within an IDE.

All of the `Start-ADOMigration...` modules are independent of one another and can be commented out or removed is that particular migration is not desired.

_(Area paths and Iteration paths need to be migrated if you plan to migrate work items with the microsoft tool)_

The `AllProjects.ps1` script is not required to run the migration modules. New scripts can be written around the modules for a more custom migration experience.

Read more about the [`AllProjects.ps1` script here](migration-scripts/README.md#AllProjects.ps1).