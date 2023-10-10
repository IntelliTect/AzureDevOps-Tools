Using Module "..\modules\Migrate-ADO-Common.psm1"

Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$FALSE)] [bool]$DoDelete = $TRUE,
        [Parameter (Mandatory=$FALSE)] [Object[]]$RepoIds = $()
)

Write-Host "Begin process to Delete Repositories for Organization $OrgName and Project $ProjectName.."

# Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT


$url = "https://dev.azure.com/$orgName/$projectName/_apis/git/repositories?api-version=7.0"
$results = Invoke-RestMethod -Method GET -uri $url -Headers $headers
$repositories = $results.Value

$repos 
if ($RepoIds.Count -gt 0) {
        $repos = $repositories | Where-Object { $_.Id -in $RepoIds }
        Write-Host "Begin Deleting set Repositories with Ids $(ConvertTo-json -Depth 100 $RepoIds)... "

} else {
        $repos = $repositories
        Write-Host "Begin Deleting ALL Repositories... "
}
Write-Host " "

foreach ($repository in $repos) {
        try {
                if($repository.name -eq $ProjectName) {
                        Write-Log -Message "Skipping the Default Repository `"$($repository.name)`" [$($repository.id)] because there must be at least one repository defined at all times.. "
                        continue
                }

                Write-Log -Message "Deleting Repository `"$($repository.name)`" [$($repository.id)].. "

                # Delete Repo to recycle bin due to soft delete 
                if($DoDelete) {
                        $url1 = "https://dev.azure.com/$OrgName/$ProjectName/_apis/git/repositories/$($repository.id)?api-version=7.0"
                        Invoke-RestMethod -Method DELETE -Uri $url1 -Headers $headers
                } else {
                        Write-Log -Message "TESTING - Test call to delete repo`"$($repository.name)`" [$($repository.id)]"
                }

                # Delete Repo from recycle bin for permanent deletion 
                if($DoDelete) {
                        $url2 = "https://dev.azure.com/$OrgName/$ProjectName/_apis/git/recycleBin/repositories/$($repository.id)?api-version=7.0"
                        Invoke-RestMethod -Method DELETE -Uri $url2 -Headers $headers
                } else {
                        Write-Log -Message "TESTING - Test call to delete repo `"$($repository.name)`" [$($repository.id)] from recylce bin"
                }
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }
}

Write-Host "End Deleting ALL Repositories found in ($OrgName/$ProjectName)... "


