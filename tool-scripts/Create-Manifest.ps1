# ----------- CONFIGURE VARIABLES HERE
$IncludedModules = @(
    "$(Get-Location)\modules\Migrate-ADO-AreaPaths.psm1",
    "$(Get-Location)\modules\Migrate-ADO-IterationPaths.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Users.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Teams.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Groups.psm1",
    "$(Get-Location)\modules\Migrate-ADO-BuildQueues.psm1",
    "$(Get-Location)\modules\Migrate-ADO-BuildEnvironments.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Repos.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Wikis.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Common.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Pipelines.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Project.psm1",
    "$(Get-Location)\modules\Migrate-ADO-ServiceHooks.psm1",
    "$(Get-Location)\modules\Migrate-ADO-ServiceConnections.psm1",
    "$(Get-Location)\modules\Migrate-ADO-VariableGroups.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Policies.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Dashboards.psm1",
    "$(Get-Location)\modules\Migrate-ADO-BuildDefinitions.psm1",
    "$(Get-Location)\modules\Migrate-ADO-ReleaseDefinitions.psm1",
    "$(Get-Location)\modules\Migrate-ADO-Artifacts.psm1",
    "$(Get-Location)\modules\Migrate-ADO-DeliveryPlans.psm1",
    "$(Get-Location)\modules\ADO-AddCustomField.psm1",
    "$(Get-Location)\modules\Migrate-Packages.psm1"
)

# Make sure files are the correct paths
$validPath = Test-Path $IncludedModules[0]

if(!$validPath){
    throw "The file paths appear to be incorrect... `n
    Make sure you are in the repo root directory when running this script."
}

$Version = '1.0.0.0'
$Description = 'Azure Devops Migration classes, functions and enums.'
$Path = "$($env:PSModulePath.Split(";")[0])\Migrate-ADO"
$FileName = "Migrate-ADO.psd1"

New-Item -Path $Path -ItemType Directory -Force

Write-Host $Path -ForegroundColor Gray

# ---------- CREATES A NEW MANIFEST FOR PACKAGED MODULES
New-ModuleManifest `
    -Path "$Path\$FileName" `
    -NestedModules $IncludedModules `
    -Guid (New-Guid) `
    -ModuleVersion $Version `
    -Description $Description `
    -PowerShellVersion 5.1.0.0