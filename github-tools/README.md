# ADO to GitHub Migration Tools

Uses existing ADO migration PowerShell modules to pull relevant information from 
Uses ado2gh tool from [GitHub Enterprise Importer CLI](https://github.com/github/gh-gei)

orgs.json
Add source organizations and ADO Pipelines service connections to  

## Setup
1. Clone repo
1. Download and unzip the latest ado2gh migratin tool from [Enterprise Importer Releases](https://github.com/github/gh-gei/releases)
2. Add a PowerShell alias for the command:
```
New-Alias ado2gh <path to ado2gh.exe>
```
3. cd to .\module-migrators folder and run 
```
.\migrationscripts\create-manfist.ps1
```
