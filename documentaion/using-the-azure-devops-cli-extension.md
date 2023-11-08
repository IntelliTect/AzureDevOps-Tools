[[_TOC_]]

## Using the Azure CLI Azure DevOps Extension

The Azure CLI will work just fine within PowerShell. However, if you want to pipe and process results, some additional steps must be taken as by default, the CLI returns results in JSON.

## Adding users to a team using the Azure CLI Azure DevOps extension and PowerShell
Basic process as follows
1. Get a list of users into a CSV
2. Get the team's security group
3. Add the users from the list to that group

### Get a list of users with their descriptors ("member id") to a CSV
We can add users to a project Using the Azure CLI and Azure DevOps extension.

Get a list of users into a PowerShell variable. 
```
$u = az devops user list | ConvertFrom-Json
```

Export users and their desciptor to a CSV. A CSV isn't strictly required but may be useful. 
```
$u.items | ForEach-Object { $_.user | select displayName, descriptor } | export-csv users.csv -NoTypeInformation
```

### Get the default team security group for a project

Get a list of all of the security groups for a given project into a PowerShell variable

```
$groups = az devops security group list --project "<project name>" | ConvertFrom-Json
```

Filter the list for the team we care about and get its descriptor/Group ID and set to $team

```
$team = $groups.graphGroups | Where-Object {$_.displayName -like "*team*"} 
```

### Add a list of users to a security group

For readability, and to veriy the list is correct, import the csv into a PowerShell variable
```
$users = Import-CSV users.csv
```

You can filter or remove users you don't want added.

Add users by piping to a the membership add command 
```
$users | ForEach-Object {az devops security group membership add --group-id $team.descriptor --member-id $_.descriptor} 
```

Users will be added to the group.

## get a list of Projects

```
$projects = az devops project list | ConvertFrom-Json                                 
```

## List all projects Area Paths to a table

Uses the list of projects to then display all area paths for each table.

Uses the ```--output table``` format for easy reading.


```
$projects | ForEach-Object {az boards area project list --depth 5 -p $_.Name -o table}
```

### List all projects iteration paths

Uses the list of projects to then display all iteration paths.

Uses the ```--output table``` format for easy reading.

```
$projects | ForEach-Object {az boards iteration project list -p $_.Name --depth 5 --output table }
```


