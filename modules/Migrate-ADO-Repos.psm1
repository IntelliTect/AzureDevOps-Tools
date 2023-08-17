
Using Module ".\Migrate-ADO-Common.psm1"

function Start-ADORepoMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName,

        [Parameter (Mandatory = $TRUE)] 
        [String]$SourcePAT,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName,

        [Parameter (Mandatory = $TRUE)] 
        [String]$TargetPAT,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$ReposPath,

        [Parameter (Mandatory=$FALSE)] 
        [Object[]]$RepoIds = $()
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate repos from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-------------------'
        Write-Log -Message '-- Migrate Repos --'
        Write-Log -Message '-------------------'
        Write-Log -Message ' '
        
        try {
            
            $sourceRepos = Get-Repos -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
            Write-Log -Message "Source repository Count $($sourceRepos.Count).."
            $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
            Write-Log -Message "Target repository Count $($targetRepos.Count).."

            $savedPath = $(Get-Location).Path

            $repos 
            if ($RepoIds.Count -gt 0) {
                $repos = $sourceRepos | Where-Object { $_.Id -in $RepoIds }
                Write-Log -Message "Repo Ids passed in Count $($repos.Count).."
            } else {
                $repos = $sourceRepos
            }

            if($repos.Count -gt 0) {

                # First clean out the temp repo directory
                $tempPath = "$ReposPath\temp"

                if (-not (Test-Path -Path $tempPath)) {
                    New-Item -Path $tempPath -ItemType Directory
                } else {
                    Get-ChildItem -Path $tempPath | Remove-Item -Recurse -Force
                }

                foreach ($sourceRepo in $repos ) {
                    Write-Log -Message "Copying repo $($sourceRepo.Name).."

                    $targetReposExists = $FALSE
                    $targetRepo = $targetRepos | Where-Object { $_.name -ieq $sourceRepo.name }
                    if ($null -ne $targetRepo) {
                        Write-Log -Message "Repo [$($sourceRepo.name)] already exists in target.. "
                        $targetReposExists = $TRUE
                    }

                    try {
                        if($targetReposExists) {
                            Write-Log -Message 'Updating existing repository.. '
                        } else {
                            Write-Log -Message 'Initializing new repository.. '
                            New-GitRepository -ProjectName $TargetProjectName -OrgName $TargetOrgName -RepoName $sourceRepo.name -Headers $TargetHeaders
                        }
                    }
                    catch {
                        Write-Log -Message "Error initializing repo: $_ " -LogLevel ERROR
                        Write-Log -Message 'Repository cannot be migrated, please migrate manually ... '
                        continue
                    }

                    try {
                        Write-Log -Message "Cloning repository $($sourceRepo.name)"

                        $remoteUrl =  $sourceRepo.remoteURL.Replace("@",":$SourcePAT@")
                        git clone --mirror $remoteUrl "$tempPath\$($sourceRepo.name)"
                        
                        Write-Log -Message "Entering path `"$tempPath\$($sourceRepo.name)`""
                        Set-Location "$tempPath\$($sourceRepo.name)"

                        Write-Log -Message 'Pushing repo ...'
                        $gitTarget = "https://$($TargetOrgName):$($TargetPAT)@dev.azure.com/$TargetOrgName/$TargetProjectName/_git/" + $sourceRepo.name
                        git push --mirror $gitTarget

                        # Write-Log -Message 'Remove local copy of repo ...'
                        # remove-Item "$tempPath\$($sourceRepo.name)" -Force -Recurse
                    }
                    catch {
                        Write-Log -Message "Error adding remote: $_" -LogLevel ERROR
                    }
                    finally {
                        Set-Location $savedPath
                    }
                } 
            }
        }
        catch {
            Write-Log -Message "Fatal-Error cloning repos from org $SourceOrgName and project $SourceProjectName" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            return
        }
    }
}
