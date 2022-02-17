# ----------- CONFIGURE VARIABLES HERE
$IncludedModules = @(
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-AreaPaths.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-IterationPaths.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-Users.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-Teams.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-Groups.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-BuildQueues.psm1",
    "$(Get-Location)\supporting-modules\Migrate-ADO-Repos.psm1",
    "$(Get-Location)\Supporting-Modules\Migrate-ADO-Common.psm1"
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