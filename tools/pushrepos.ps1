Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetOrgName = $targetOrgName,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,
    [string]$WorkingDir = $WorkingDir,
    [Parameter(Mandatory=$True)][PSCustomObject[]]$Repos
)
. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1


Write-Log -msg " "
Write-Log -msg "----------------"
Write-Log -msg "-- Push Repos --"
Write-Log -msg "----------------"
Write-Log -msg " "

$savedPath = $(Get-Location).Path

$targetHeaders = New-HttpHeaders -pat $targetPat -org $targetOrg
$targetProject = Get-ADOProjects -headers $targetHeaders -org $targetOrg -projectName $TargetProjectName
$targetRepos = Get-Repos -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg

foreach ($repo in $Repos) {

    Write-Host "Pushing repo " + $repo.Name

    $targetRepo = $targetRepos | Where-Object {$_.name -ieq $repo.name}
    if ($null -eq $targetRepo) {
        try {
            "Initializing repository ... "
            New-GitRepository -org $targetOrg -projectID $targetProject.id -reponame $repo.name -pat $targetPat
        }
        catch {
            Write-Log -logLevel "ERROR" -msg "Error initializing repo: $_ "
        }
    }

    try {
        "Pushing repo ..."
        "Entering path `"$WorkingDir\$($repo.name)`""
        Set-Location "$WorkingDir\$($repo.name)"

        $tempStr = "$($TargetOrg -replace "https://","https://$TargetOrgName@")"
        #$targetB64Pat = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($targetPat))

        $gitTarget = "$tempStr/$TargetProjectName/_git/"+$repo.name
        $gitTarget

        git remote add target $gitTarget
        git push -u target --all
    }
    catch {
        Write-Log -logLevel "ERROR" -msg "Error adding remote: $_"
    }
    finally {
        Set-Location $savedPath
    }
}