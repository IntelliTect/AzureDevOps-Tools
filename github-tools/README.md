# ADO to GitHub Migration Tools

Uses existing ADO migration PowerShell modules to pull relevant information from 
Uses ado2gh tool from [GitHub Enterprise Importer CLI](https://github.com/github/gh-gei)

## Tooling Setup
1. Clone repo
1. Download and unzip the latest ado2gh migratin tool from [Enterprise Importer Releases](https://github.com/github/gh-gei/releases)
2. Add a PowerShell alias for the command:
```
New-Alias ado2gh <path to ado2gh.exe>
```
3. cd to .\module-migrators folder and run 
```
.\migration-scripts\create-manifest.ps1
```

## GitHub and ADO Organization Setup
- Install the ADO Boards app in the target GitHub org
- Install the ADO Pipelines app in the target GitHub org
- Configure one Pipelines Service Connection in the source ADO org and note its object ID
- Update orgs.json with ADO org name and corresponding service connection ID

