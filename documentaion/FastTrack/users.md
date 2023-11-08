# Azure DevOps Service Users 

The Azure DevOps graph API is used to query and manage users.

It requires OAuth. It will work from a validated browser session. If running from a script, an OAuth token will need to be created.

API end point: https://vssps.dev.azure.com/{orgname}/_apis/graph/users?api-version=5.1-preview.1

OAuth app registration to allow interaction to graph from app/script: 
https://docs.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops

You can navigate to the api endpoint from an authenticated web browser and save the result as json. Once saved as json, PowerShell can be used.

```
$users = Get-Content -Path users.json | ConvertFrom-Json
$users.value.Where({$_.origin -like "aad"}) | select principalName, displayName
```
origin values of vsts are service accounts created by Azure DevOps

Export the list to a csv:
```
$users.value.Where({$_.origin -like "aad"}) | select principalName, displayName  | Export-csv users.csv
```

Help
