
Using Module "..\modules\Migrate-ADO-Common.psm1"

Param(
    [string]$SourcePat,
    [string]$SourceOrg,
    [string]$SourceProjectName
    # [string]$TargetPat,
    # [string]$TargetOrg,
    # [string]$TargetProjectName
)

# . .\AzureDevOps-Helpers.ps1
# . .\AzureDevOps-ProjectHelpers.ps1


Write-Log -Message " "
Write-Log -Message "-----------------"
Write-Log -Message "-- Clone Repos --"
Write-Log -Message "-----------------"
Write-Log -Message " "

try {
    $sourceHeaders = New-HttpHeaders -PersonalAccessToken $SourcePat 
    # $targetHeaders = New-HttpHeaders -PersonalAccessToken $TargetPat 

    $repos = Get-Repos -projectName $SourceProjectName -orgName $SourceOrg  -headers $sourceHeaders
    # $targetRepos = Get-Repos -projectName $TargetProjectName -orgName $TargetOrg  -headers $targetHeaders
    $final = [array]@()

    foreach ($repo in $repos) {

        # if ($null -ne ($targetRepos | Where-Object {$_.name -ieq $repo.name})) {
        #     Write-Log -Message "Repo [$($repo.name)] already exists in target.. " 
        #     continue
        # }

        Write-Host "Cloning $($repo.name)"
        # git clone $repo.remoteURL "`"$WorkingDir\$($repo.name)`""
        $final += $repo
    } 
    return $final
}
catch {
    Write-Error "Error cloning repos from org $sourceOrg and project $SourceProjectName"
    Write-Error $_
    return
}

