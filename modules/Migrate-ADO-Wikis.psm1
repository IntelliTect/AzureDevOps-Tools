
Using Module ".\Migrate-ADO-Common.psm1"

function Start-ADOWikiMigration {
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
        [String]$ReposPath
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate wiki from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-------------------'
        Write-Log -Message '-- Migrate Wikis --'
        Write-Log -Message '-------------------'
        Write-Log -Message ' '

       try {
            $sourceWikis = Get-Wikis -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
            $targetWikis = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
            $savedPath = $(Get-Location).Path

            foreach ($sourceWiki in $sourceWikis) {
                
                $sourceRepo = Get-Repo -ProjectName $SourceProjectName -org $SourceOrgName -headers $sourceHeaders -repoId $sourceWiki.name

                if ($null -ne ($targetWikis | Where-Object { $_.name -ieq $sourceWiki.name })) {
                    Write-Log -Message "Wiki/repo [$($sourceWiki.name)] already exists in target.. "
                    continue
                }
        
                try {
                    Write-Log -Message 'Initializing new wiki repository ... '
                    New-GitRepository -ProjectName $TargetProjectName -OrgName $TargetOrgName -RepoName $sourceRepo.name -Headers $TargetHeaders
                }
                catch {
                    Write-Log -Message "Error initializing new wiki repo: $_ " -LogLevel ERROR
                    Write-Log -Message 'Repository cannot be migrated, please migrate manually ... '
                    continue
                }

                try {
                    Write-Log -Message "Cloning wiki repository $($sourceRepo.name)"
                    $remoteUrl =  $sourceRepo.remoteURL.Replace("@",":$SourcePAT@")
                    git clone --mirror $remoteUrl "$ReposPath\$($sourceRepo.name)"
                    
                    Write-Log -Message "Entering path `"$ReposPath\$($sourceRepo.name)`""
                    Set-Location "$ReposPath\$($sourceRepo.name)"

                    Write-Log -Message 'Pushing repo ...'
                    $gitTarget = "https://$($TargetOrgName):$($TargetPAT)@dev.azure.com/$TargetOrgName/$TargetProjectName/_git/" + $sourceRepo.name
                    git push --mirror $gitTarget

                    # Write-Log -Message 'Remove local copy of repo ...'
                    # remove-Item "$ReposPath\$($sourceRepo.name)" -Force -Recurse
                }
                catch {
                    Write-Log -Message "Error adding remote: $_" -LogLevel ERROR
                }
                finally {
                    Set-Location $savedPath
                }
            } 
        }
        catch {
            Write-Log -Message "Error cloning wiki/repo from org $SourceOrgName and project $SourceProjectName" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            return
        }
    }
}


# Wikis
function Get-Wikis([string]$projectName, [string]$orgName, $headers) {
    $url = "https://dev.azure.com/$orgName/$projectName/_apis/wiki/wikis?api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value
}

function Get-Wiki([string]$projectName, [string]$orgName, $headers, $wikiIdentifier) {
    $url = "https://dev.azure.com/$orgName/$projectName/_apis/wiki/wikis/$($wikiIdentifier)?api-version=7.0"
    
    $results =  Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value
}


