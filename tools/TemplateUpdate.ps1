import-module TFSAdminFunctions

$TeamProjectName = "<ADD PROJECT NAME>"
$ProcessTemplateRoot = Get-Location
$CollectionUrl = "<ADD COLLECTION URL HERE>"

# Make sure we only run what we need
[datetime] $lastImport
$UpdateFilePath = ".\UpdateTemplate.txt"
if ((Test-Path $UpdateFilePath) -eq $true)
{
  $UpdateFile = Get-Item -Path $UpdateFilePath
  $lastImport = $UpdateFile.LastWriteTime
} else {
  $lastImport = [datetime]::MinValue
}
Write-Output "Last Import was $lastImport"

Invoke-TFSWITAdmin
Invoke-TFSWITAdmin_RenameWITD -TFSProjectCollectionUrl $CollectionUrl -Project $TeamProjectName -CurrentTypeName "Product Backlog Item" -NewTypeName "User Story"
Invoke-TFSWITAdmin_RenameWITD -TFSProjectCollectionUrl $CollectionUrl -Project $TeamProjectName -CurrentTypeName "Impediment" -NewTypeName "Issue"

$lts = Get-ChildItem "$ProcessTemplateRoot\Microsoft Visual Studio Scrum 2013.5\WorkItem Tracking\LinkTypes" -Filter "*.xml"
foreach( $lt in $lts)
{
    if ($lt.LastWriteTime -gt $lastImport)
    {
        Invoke-TFSWITAdmin_ImportLinkType -TFSProjectCollectionUrl $CollectionUrl -LinkTypeFullName $lt.FullName
    } 
    else {
        Write-Host "-Skipping $lt"
    }
}

$witds = Get-ChildItem "$ProcessTemplateRoot\Microsoft Visual Studio Scrum 2013.5\WorkItem Tracking\TypeDefinitions" -Filter "*.xml"
foreach( $witd in $witds)
{
    if ($witd.LastWriteTime -gt $lastImport)
    {
        Invoke-TFSWITAdmin_ImportWITD -TFSProjectCollectionUrl $CollectionUrl -Project $TeamProjectName -FileName $witd.FullName
    } else {
        Write-Host "-Skipping $witd"
    }
}

$ProcessConfig = Get-Item "$ProcessTemplateRoot\Microsoft Visual Studio Scrum 2013.5\WorkItem Tracking\Process\ProcessConfiguration.xml"
if ($ProcessConfig.LastWriteTime -gt $lastImport)
{
    Invoke-TFSWITAdmin_ImportProcessConfig -TFSProjectCollectionUrl $CollectionUrl -Project $TeamProjectName -FileName $ProcessConfig.FullName
} else {
    Write-Host "-Skipping $($ProcessConfig.name)"
}