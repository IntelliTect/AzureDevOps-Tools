#Project and Process Tools

PowerShell scripts used to list process templates, projects, retrieve custom fields and custom lists from an existing TFS XML based process definition

## Getting Started

Each of the commands needs and HTTP Header and an Azure DevOps Organization

### HTTP Header
These commands call the Azure DevOps REST API using a Personal Access Token or PAT. It is supplied to Azure DevOps with an HTTP header. The New-HTTPHeaders command will create a header that can be used in subsequent calls.

### Azure DevOps Organization
An Organization parameter is used to prefix the REST calls. If calling Azure DevOps Services use the form:

```
https://dev.azure.com/<organizationame>
```

If calling Azure DevOps Server, use the default collection url:

```
http<s>://<server>/<collection>
```

### Caveats and conditions

The tools are utilities to be used when needed. They are not necessarily hardened or intended for wide-spread adoption. Rather, it's modify as you go to get what you need, approach as typically these tools are used for a migration and then potentially never touched again.

Rest APIs are easy to call using Invoke-RestMethod or using HTTPClient which is handy if and when more control over headers is desired.


- These tools are not intended to replace the Azure DevOps CLI
- The tools will sometimes simplify the options or data returned by a method. If this is an issue, add or extend as needed

## AzureDevOps-Helpers

Load the helpers into powershell context to run

```
. .\AzureDevOps-Helpers.ps1
```

To make the commands easier to use, edit/update the init.ps1 to set some commonly used variables for alter

```
. .\init.ps1
```

### New-HTTPHeaders
Create an HTTP Header that can be used in subsequent calls

```
$headers = New-HTTPHeaders -Pat $pat
```

### Get-ADOProcesses

Return all processes defined in the specified organization

```
$processes = Get-ADOProcesses -Headers $headers -Org $org 
```

To return details for a specific process, add the -ProcessName parameter

### Get-ADOProjects

Return all projects defined in an organization.

```
$projects = Get-ADOProjects -Headers $headers -Org $org 
```

To return the details of a specific project, add the -Proje tName parameter

### Get-ADOProjectProperties

Return the project properties for the specified project

```
$projectProperties = Get-ADOProjectProperties -Headers $headers -Org $org -ProjectId <projectId> 
```

Returns properties for a given project specified by its project id

Add -PropertyKey to return a specific property

### Get-ADOProjectProcessTemplates
Returns a list of projects and the process template used by the project.

```
$projectTemplates = Get-ADOProjectProcessTemplates -Headers $headers -Org $org
```

### Get-ProjectSummaries 
Returns a summary of project (or all projects) in a given organization. Sanple output
#### Parameters
 - [Required] Headers - headers generated in previous steps
 - [Required] Org - organization including https://
 - [Optional] ProjectName - Specific project you want a summary for
 - [Optional] OutFile - CSV Output file path

#### Sample Console Output
```
Name                           Value
----                           -----
largestRepoName                IParcelTest
id                             31c5c4b7-7979-469f-8489-4de88563a67f
repoCount                      1
releaseDefinitionCount         0
workItemCount                  1
policyCount                    0
name                           IParcelTest
serviceHookCount               3
buildDefinitionCount           0
largestRepoSize                0
largestRepoProjectName         IParcelTest
workItemLastChanged            2020-02-14T17:53:57.587Z
serviceEndpointCount           0
teamCount                      1
```