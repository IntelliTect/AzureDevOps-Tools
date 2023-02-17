Param(
    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "-----------------"
Write-Log -msg "-- Clone Repos --"
Write-Log -msg "-----------------"
Write-Log -msg " "

try {
    $sourceHeaders = New-HttpHeaders -pat $sourcePat -org $sourceOrg
    $repos = Get-Repos -org "$SourceOrg" -ProjectSK $SourceProjectName -headers $sourceHeaders
    $targetRepos = Get-Repos -org "$TargetOrg" -ProjectSK $TargetProjectName -headers $targetHeaders
    $final = [array]@()

    foreach ($repo in $repos) {

        if ($null -ne ($targetRepos | Where-Object {$_.name -ieq $repo.name})) {
            Write-Log -msg "Repo [$($repo.name)] already exists in target.. "  -NoNewline
            continue
        }

        Write-Host "Cloning $($repo.name)"
        git clone $repo.remoteURL "`"$WorkingDir\$($repo.name)`""
        $final += $repo
    } 
    return $final
}
catch {
    Write-Error "Error cloning repos from org $sourceOrg and project $SourceProjectName"
    Write-Error $_
    return
}

