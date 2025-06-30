
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

        [Parameter (Mandatory = $FALSE)] 
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
            $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName `
                -Headers $TargetHeaders

            $sourceRepos = Get-Repos -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
            Write-Log -Message "Source repository Count $($sourceRepos.Count).."
            $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
            Write-Log -Message "Target repository Count $($targetRepos.Count).."

            $repos 
            if ($RepoIds.Count -gt 0) {
                $repos = $sourceRepos | Where-Object { $_.Id -in $RepoIds }
                Write-Log -Message "Repo Ids passed in Count $($repos.Count).."
            }
            else {
                $repos = $sourceRepos
            }

            if ($repos.Count -gt 0) {
                $count = 1
                
                foreach ($sourceRepo in $repos ) {
                    Write-Log -Message "Migrating repo $($sourceRepo.Name), $($count) of $($sourceRepos.count)"
                    $count += 1
                    
                    $targetRepo = $targetRepos | Where-Object { $_.name -ieq $sourceRepo.name }
                    if ($null -ne $targetRepo) {
                        Write-Log -Message "Repo [$($sourceRepo.name)] already exists in target.. "
                        continue
                    }
                    if ($sourceRepo.isDisabled -eq $true) {
                        Write-Log -Message "Unable to migrate [$($sourceRepo.name)] it is disabled."
                        continue
                    }

                    try {
                        $newRepo = New-GitRepository -ProjectName $TargetProjectName -OrgName $TargetOrgName `
                            -RepoName $sourceRepo.name -Headers $TargetHeaders

                        $gitService = @{
                            "name"          = "$($sourceRepo.name)-migrate-endpoint"
                            "type"          = "git"
                            "url"           = $sourceRepo.remoteUrl
                            "authorization" = @{
                                "scheme"     = "UsernamePassword"
                                "parameters" = @{
                                    "username" = "john.leach1"
                                    "password" = $SourcePAT
                                }
                            }
                        }
                            
                        $sep = New-ServiceEndpoint -OrgName $TargetOrgName -ProjectName $targetProject.id `
                            -Headers $TargetHeaders -ServiceEndpoint $gitService
                            
                        Write-Log -Message "Starting import of repo: $($newRepo.name)."

                        $request = New-RepositoryImportRequest -OrgName $TargetOrgName -ProjectName `
                            $TargetProjectName -RepositoryName $sourceRepo.name -Headers $TargetHeaders `
                            -GitSourceUri $sourceRepo.remoteUrl -ServiceEndpointId $sep.id

                        $status
                        $timeout = 960
                        $isRunning = $true

                        for ($index = 0; $index -lt $timeout -AND $isRunning; $index++) {
                            $status = Get-RepositoryImportRequest -OrgName $TargetOrgName -ProjectName `
                                $TargetProjectName -Headers $TargetHeaders -RepositoryId $newRepo.id `
                                -ImportRequestId $request.importRequestId

                            Write-Log -Message "-- Import status: $($status.status)"
                            $isRunning = $status.status -ne "completed"

                            if ($isRunning) {
                                Start-Sleep -Seconds 4
                            }
                        }

                        Set-RepositoryDefaultBranch -ProjectName $TargetProjectName -OrgName $TargetOrgName `
                            -RepositoryId $newRepo.id -Headers $TargetHeaders -defaultBranch $sourceRepo.defaultBranch

                        Write-Log -Message "Migration of repo: $($newRepo.name) complete."

                    }
                    catch {
                        Write-Log -Message "Error migrating repo: $($sourceRepo.name) " -LogLevel ERROR
                        Write-Log -Message 'Repository cannot be migrated, please migrate manually... '
                        Write-Log -Message $_ -LogLevel ERROR
                        continue
                    }
                } 
            }
        }
        catch {
            Write-Log -Message "Fatal-Error migrating repos from org $SourceOrgName and project $SourceProjectName" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            Write-Log -Message $_ -LogLevel ERROR
            return
        }
    }
}

function Get-RepositoryRefs {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string] $OrgName,

        [Parameter(Mandatory = $TRUE)]
        [string] $ProjectName,

        [Parameter(Mandatory = $TRUE)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $TRUE)]
        [string] $RepositoryId
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/git/repositories" `
        + "/$($RepositoryId)/refs?api-version=7.1"

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results
}

function Get-RepositoryImportRequest {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string] $OrgName,

        [Parameter(Mandatory = $TRUE)]
        [string] $ProjectName,

        [Parameter(Mandatory = $TRUE)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $TRUE)]
        [string] $RepositoryId,

        [Parameter(Mandatory = $TRUE)]
        [string] $ImportRequestId
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/git/repositories/" `
        + "$($RepositoryId)/importRequests/$($ImportRequestId)?api-version=7.1"

    $result = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $result
}

function New-RepositoryImportRequest {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string] $OrgName,

        [Parameter(Mandatory = $TRUE)]
        [string] $ProjectName,

        [Parameter(Mandatory = $TRUE)]
        [string] $RepositoryName,

        [Parameter(Mandatory = $TRUE)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $TRUE)]
        [string]
        $GitSourceUri,
        
        [Parameter(Mandatory = $TRUE)]
        [string]
        $ServiceEndpointId
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/git/repositories/$($RepositoryName)" `
        + "/importRequests?api-version=7.1"

    $body = ConvertTo-Json -Depth 32 @{
        "parameters" = @{
            "deleteServiceEndpointAfterImportIsDone" = $true
            "gitSource"                              = @{
                "overwrite" = $false
                "url"       = $GitSourceUri
            }
            "serviceEndpointId"                      = $ServiceEndpointId
        }
    }

    $result = Invoke-RestMethod -Method Post -Uri $url -Body $body -Headers $Headers -ContentType `
        "application/json"

    return $result
}

function Set-RepositoryDefaultBranch {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string] $OrgName,

        [Parameter(Mandatory = $TRUE)]
        [string] $ProjectName,

        [Parameter(Mandatory = $TRUE)]
        [string] $RepositoryId,

        [Parameter(Mandatory = $TRUE)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $TRUE)]
        [string]  $defaultBranch
    )

    Write-Log -Message "Setting default branch to $($sourceRepo.defaultBranch)."

    $branches
    $retries = 4
    $isRunning = $true

    for ($index = 0; $index -lt $retries -AND $isRunning; $index++) {
        $branches = Get-RepositoryRefs -OrgName $OrgName -ProjectName $ProjectName `
            -Headers $Headers -RepositoryId $RepositoryId

        $isRunning = $branches.Count -eq 0

        if ($isRunning) {
            Start-Sleep -Seconds 4
        }
    }

    $query = $branches.value | Where-Object { $_.name -eq $defaultBranch }

    if ($query) {
        $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/git/repositories/$($RepositoryId)" `
            + "?api-version=7.1"

        $body = ConvertTo-Json -Depth 32 @{
            "defaultBranch" = $defaultBranch
        }

        Invoke-RestMethod -Method Patch -Uri $url -ContentType "application/json" `
            -Body $body -Headers $Headers
    }
    else {
        Write-Log -Message "WARNING: Unable to find branch $($sourceRepo.defaultBranch)."
    }
}

function Start-ADORepoMigration-Old {
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

        [Parameter (Mandatory = $FALSE)] 
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
            }
            else {
                $repos = $sourceRepos
            }

            if ($repos.Count -gt 0) {

                # First clean out the temp repo directory
                $tempPath = "$ReposPath\temp"

                if (-not (Test-Path -Path $tempPath)) {
                    New-Item -Path $tempPath -ItemType Directory
                }
                else {
                    Get-ChildItem -Path $tempPath | Remove-Item -Recurse -Force
                }

                foreach ($sourceRepo in $repos ) {
                    Write-Log -Message "Copying repo $($sourceRepo.Name).."

                    # $targetReposExists = $FALSE
                    $targetRepo = $targetRepos | Where-Object { $_.name -ieq $sourceRepo.name }
                    if ($null -ne $targetRepo) {
                        Write-Log -Message "Repo [$($sourceRepo.name)] already exists in target.. "
                        continue
                        # $targetReposExists = $TRUE
                    }

                    try {
                        # if($targetReposExists) {
                        #     Write-Log -Message 'Updating existing repository.. '
                        # } else {
                        Write-Log -Message 'Initializing new repository.. '
                        New-GitRepository -ProjectName $TargetProjectName -OrgName $TargetOrgName -RepoName $sourceRepo.name -Headers $TargetHeaders
                        # }
                    }
                    catch {
                        Write-Log -Message "Error initializing repo: $_ " -LogLevel ERROR
                        Write-Log -Message 'Repository cannot be migrated, please migrate manually ... '
                        continue
                    }

                    try {
                        Write-Log -Message "Cloning repository $($sourceRepo.name)"

                        $remoteUrl = $sourceRepo.remoteURL.Replace("@", ":$SourcePAT@")
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
