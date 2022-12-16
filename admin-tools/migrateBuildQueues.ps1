Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "--------------------------"
Write-Log -msg "-- Migrate Build Queues --"
Write-Log -msg "--------------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$queues = Get-BuildQueues -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders
$targetQueues = Get-BuildQueues -projectSk $targetProject.id -org $TargetOrg -headers $targetHeaders

foreach ($queue in $queues) {
    if ($queue.pool.isHosted -or $queue.pool.name -eq "Default") {
        continue
    }

    if ($null -ne ($targetQueues | Where-Object {$_.name -ieq $queue.name})) {
        Write-Log -msg "Build queue [$($queue.name)] already exists in target.. "  -NoNewline
        continue
    }

    Write-Log -msg "Attempting to create [$($queue.name)] in target.. "  -NoNewline
    try {
        New-BuildQueue -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -queue @{
            "projectId"     = $queue.projectId
            "name"          = $queue.name
            "id"            = $queue.id
        }
        Write-Log -msg "Done!" -ForegroundColor "Green"
    }
    catch {
        Write-Log -msg "FAILED!" -ForegroundColor "Red"
        Write-Log -msg ($_ | ConvertFrom-Json).message -ForegroundColor "Red"
    }
}
