[[_TOC_]]

# Using the Azure CLI Azure DevOps Extension

The [Auzre CLI](), Azure's Command Line Intepreter, supports an extension for DevOps. The CLI is designed to be cross platform, but  will work just fine within PowerShell. 

The CLI will return results as JSON by default. Use the ConvertFrom-Json function to convert the results into an object that can be easily manipulated by PowerShell.

# Projects

## Get a list of Projects

```
$projects = $(az devops project list | ConvertFrom-Json).value
```
az devops project list returns a result set including a continuationToken and the projects json. The above command converts the result to a PowerShell object and selects the value property

The following command will then display a filter list of results. The $projects variable can be used to perform functions on projects

```
$projects | select name, id
```

## List all projects Area Paths to a table

```
$projects | ForEach-Object {az boards area project list --depth 5 -p $_.Name -o table}
```
This command iterates on the list of projects and then uses the az boards area command to display all area paths.

Note the use of  ```-o table``` which formats the output for easy reading.

## List all projects iteration paths

```
$projects | ForEach-Object {az boards iteration project list -p $_.Name --depth 5 --output table }
```
Iterates the projects list to run the az boards iteratio command

Uses the ```--output table``` format for easy reading.

# Security Groups



# Add users to a team with the Azure CLI Azure DevOps extension and PowerShell
Basic process as follows:
1. Export a list of users into a CSV
2. Find the team's security group
3. Add the users from the CSV to the security group

## Get a list of users with their descriptors ("member id") to a CSV
We can add users to a project Using the Azure CLI and Azure DevOps extension.

Get a list of users into a PowerShell variable. 
```
$u = az devops user list | ConvertFrom-Json
```

Export users and their desciptor to a CSV. A CSV isn't strictly required but may be useful. 
```
$u.items | ForEach-Object { $_.user | select displayName, descriptor } | export-csv users.csv -NoTypeInformation
```

## Get the default team security group for a project

Get a list of all of the security groups for a given project into a PowerShell variable

```
$groups = az devops security group list --project "<project name>" | ConvertFrom-Json
```

Filter the list for the team we care about and get its descriptor/Group ID and set to $team

```
$team = $groups.graphGroups | Where-Object {$_.displayName -like "*team*"} 
```

## Add a list of users to a security group

For readability, and to veriy the list is correct, import the csv into a PowerShell variable
```
$users = Import-CSV users.csv
```

You can filter or remove users you no longer need by editing the users.csv.

Add users by piping to a the membership add command 
```
$users | ForEach-Object {az devops security group membership add --group-id $team.descriptor --member-id $_.descriptor} 
```

Users will be added to the group.

