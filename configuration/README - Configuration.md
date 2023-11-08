
# "configuration" Directory 
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
<br />

**VSTS Only** means that the configuration property is only required if you are using the VSTS work item migrator.



## base-configuration.json ([VSTS only](https://github.com/microsoft/vsts-work-item-migrator)) 
#### (If using the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator)):
A pre-configured configuration file used by the [Microsoft VSTS Work Item Migrator tool](https://github.com/microsoft/vsts-work-item-migrator).
Read more about [base-configuration here](https://github.com/microsoft/vsts-work-item-migrator/blob/master/WiMigrator/migration-configuration.md)
<br /> <br />

## migrator-configuration.json

The migrator-configuration.json file is use in conjunction with the Azure DevOps Migration Tools (aka. Martin's Tool). This tool is used to migration Work-Items and other areas of data. When running a full project migration using the PowerShell script MigrateProject.ps1, this file is automatically configured for you based on your selections of area or migration. You can configure this file manually and run the tool separately from the MigrateProject.ps1 tool if deisred. 


