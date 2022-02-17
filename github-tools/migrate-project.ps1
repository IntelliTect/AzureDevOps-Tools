param(
    [string]$sourceOrg, 
    [string]$sourceProjectName, 
    [string]$targetOrg, 
    [string]$targetProjectName, 

    [string]$OutFile, 
    [int]$BatchSize = 50
)

if (string.IsEmpty($env:ADO_PAT)) {
    "ADO_PAT not set!"
    return
}
if (string.Empty($env:GH_PAT)) {
    "GH_PAT not set!"
}

