function Start-ADOWikiMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName,

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

        $wikiReposToPush = Copy-Wikis `
            -SourceProjectName $SourceProjectName `
            -SourceOrgName $SourceOrgName `
            -SourceHeaders $sourceHeaders `
            -TargetProjectName $TargetProjectName `
            -TargetOrgName $TargetOrgName `
            -TargetHeaders $TargetHeaders `
            -ReposPath $ReposPath

        Push-Repos `
            -ProjectName $TargetProjectName `
            -OrgName $TargetOrgName `
            -Repos $wikiReposToPush `
            -Headers $TargetHeaders `
            -ReposPath $ReposPath
    }
}

function Copy-Wikis {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = " https://dev.azure.com/$OrgName/$ProjectName/_apis/wiki/wikis?api-version=7.0"
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results.value
    }
}

function Copy-Wikis {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$ReposPath
    )
    if ($PSCmdlet.ShouldProcess("path $ReposPath")) {
        try {
            $final = [object[]]@()

            # $targetWikis = Get-Wikis -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
            $sourceWikis = Get-Wikis -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders

            foreach ($sourceWiki in $sourceWikis) {
                
                $sourceRepo = Get-Repo -ProjectName $SourceProjectName -org $SourceOrgName -headers $sourceHeaders -repoId $sourceWiki.name

                # if ($null -ne ($targetWikis | Where-Object { $_.name -ieq $sourceWiki.name })) {
                if ($null -ne $targetWiki) {
                    Write-Log -Message "Wiki/repo [$($sourceWiki.name)] already exists in target.. "
                    continue
                }
        
                Write-Log -Message "Cloning $($sourceWiki.name)"
                git clone $sourceRepo.remoteURL "$ReposPath\$($sourceWiki.name)"
                $final += $sourceWiki
            } 
            return $final
        }
        catch {
            Write-Log -Message "Error cloning wiki/repo from org $SourceOrgName and project $SourceProjectName" -LogLevel ERROR
            Write-Error -Messsage $_ -LogLevel ERROR
            return
        }
    }
}

function Push-Repos {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Object[]]$Repos,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$ReposPath
    )
    if ($PSCmdlet.ShouldProcess($ProjectName, "Push repos from $ReposPath")) {
        $savedPath = $(Get-Location).Path
        $targetRepos = Get-Wikis -ProjectName $ProjectName -OrgName $OrgName -Headers $Headers
        
        foreach ($repo in $Repos) {
            Write-Log -Message "Pushing repo $($repo.Name)"
        
            $targetRepo = $targetRepos | Where-Object { $_.name -ieq $repo.name }
            if ($null -eq $targetRepo) {
                try {
                    Write-Log -Message 'Initializing repository ... '
                    New-GitRepository -ProjectName $ProjectName -OrgName $Orgname -RepoName $repo.name -Headers $Headers
                }
                catch {
                    Write-Log -Message "Error initializing repo: $_ " -LogLevel ERROR
                }
            }
        
            try {
                Write-Log -Message 'Pushing repo ...'
                Write-Log -Message "Entering path `"$ReposPath\$($repo.name)`""
                Set-Location "$ReposPath\$($repo.name)"

                $gitTarget = "https://$TargetOrgName@dev.azure.com/$TargetOrgName/$TargetProjectName/_git/" + $repo.name
        
                git remote add target $gitTarget
                git push -u target --all
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

function New-GitRepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$RepoName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName, "Push repos from $ReposPath")) {
        $url = "$org/_apis/git/repositories?api-version=5.1"
    }
    $url = "https://dev.azure.com/$OrgName/_apis/git/repositories?api-version=5.1"

    $project = Get-ADOProjects -OrgName $OrgName -ProjectName $ProjectName -Headers $Headers

    $requestBody = @{
        name    = $RepoName
        project = @{
            id = $project.id
        }
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Method post -uri $url -Headers $Headers -Body $requestBody -ContentType 'application/json'
    }
    catch {
        Write-Log -Message "Error creating repo $RepoName in project $projectId : $($_.Exception) " 
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
