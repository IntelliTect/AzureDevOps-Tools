
function Start-ADOArtifactsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] 
        [String]$SourceOrgName, 

        [Parameter (Mandatory = $TRUE)] 
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)] 
        [string]$SourcePAT,

        [Parameter (Mandatory = $TRUE)] 
        [String]$TargetOrgName, 

        [Parameter (Mandatory = $TRUE)] 
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)] 
        [Hashtable]$TargetHeaders,

        [Parameter (Mandatory = $TRUE)] 
        [string]$TargetPAT,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectPath,

        [Parameter (Mandatory = $TRUE)]
        [Int]$ArtifactFeedPackageVersionLimit
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Artifacts from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '------------------------'
        Write-Log -Message '-- Migrate Artifacts --'
        Write-Log -Message '-----------------------'
        Write-Log -Message ' '


        $sourceFeeds = Get-Feeds -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders
        $targetFeeds = Get-Feeds -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders 

         # Get the Target Organization ID to be used for the internalUpstreamCollectionId value when creating internal Upstream Sources
         $targetInternalUpstreamCollectionId = Get-OrganizationId -OrgName $TargetOrgName -Headers $TargetHeaders

        # Create all Target Feeds before adding packages to each feed
        $newTargetFeeds = @()
        foreach ($feed in $sourceFeeds) {
            $existingFeed = $targetFeeds | Where-Object { $_.Name -ieq $feed.Name }
            if ($null -ne $existingFeed) {
                Write-Log -Message "Feed [$($feed.Name)] already exists in target.. "
                $newTargetFeeds += $existingFeed
                continue
            }

            Write-Log -Message "Creating New Feed [$($feed.Name)] in target.. "
            # Create the target Feed first with public type upstream sources and then update the feeds internal upstream sources after all the feeds have been created 
           
            $publicUpstreamSources = @()
            foreach ($source in $feed.upstreamSources) {
                if($source.upstreamSourceType -eq "public") {
                    $publicUpstreamSources += $source
                }
            }

           $targetFeed = New-ADOFeed -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -SourceFeed $feed -UpstreamSources $publicUpstreamSources
           Write-Log "Feed Name: $($feed.name)"
           Write-Log "Command: New-ADOFeed -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -SourceFeed $feed -UpstreamSources $publicUpstreamSources"
           Write-Log "TargetFeed: $targetFeed"
            if(($NULL -eq $targetFeed) -or ($targetFeed.GetType().Name -eq "FileInfo")) { 
                if ($null -eq $targetFeed) {
                    Write-Log -Message "Could not create a new feed with name '$($feed.Name)'. The feed name may be reserved by the system." -LogLevel ERROR
                } 
                continue 
            } else {
                # Make sure that the target view access is the same as the source view access 
                $sourceViews = Get-Views -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders -FeedId $feed.Id
                $targetViews = Get-Views -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -FeedId $targetFeed.Id

                foreach ($targetView in $targetViews) {
                        $sourceView = $sourceViews | Where-Object { $_.name -ieq $targetView.name } 
                        if($NULL -ne $sourceView) {
                            if($targetView.visibility -ine $sourceView.visibility ) {
                                Update-View -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -FeedId $targetFeed.Id -ViewId $targetView.Id -Visibility $sourceView.visibility
                            }
                        }
                }

                Write-Log -Message "Done!" -LogLevel SUCCESS
                $newTargetFeeds += $targetFeed
            }
        }


        # DO UPDATE OF THE FEEDS WITH INTERNAL UPSTREAM SOURCES 
        foreach ($feed in $sourceFeeds) {
            $internalUpstreamSources = @()
            foreach ($source in $feed.upstreamSources) {
                if($source.upstreamSourceType -eq "internal") {
                    $internalUpstreamSources += $source
                }
            }

            
            if ($internalUpstreamSources.count -gt 0) {
                Write-Log -Message "Validating and updating Internal Upstream Sources for [$($feed.Name)] in target.. "

                $existingSourceFeed = $newTargetFeeds | Where-Object { $_.Name -ieq $feed.Name }

                $upstreamSources = $existingSourceFeed.upstreamSources
                foreach ($internalSource in $internalUpstreamSources) {
                    $existingSounceFeedSource = $existingSourceFeed.upstreamSources | Where-Object { $_.Name -ieq $internalSource.Name }
                    if ($null -ne $existingSounceFeedSource) {
                        Write-Log -Message "Feed [$($feed.Name)] internal Upstream Source [$($internalSource.Name)] already exists in target Feed.. "
                        continue
                    }
                    Write-Log "Display Location: $($internalSource.displayLocation)" 
                    if($internalSource.displayLocation -like "*$SourceOrgName/$SourceProjectName*") {
                        $sourceInternalUpstreamFeed = Get-Feed -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders -FeedId $internalSource.internalUpstreamFeedId
                        $sourceInternalUpstreamFeedViews = Get-Views -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders -FeedId $sourceInternalUpstreamFeed.Id
                        $sourceInternalUpstreamFeedView = $sourceInternalUpstreamFeedViews | Where-Object { $_.Id -eq $internalSource.internalUpstreamViewId }
                        
                        $targetInternalUpstreamFeed = $newTargetFeeds | Where-Object { $_.name -eq $sourceInternalUpstreamFeed.Name }
                        $targetInternalUpstreamFeedViews = Get-Views -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -FeedId $targetInternalUpstreamFeed.Id
                        $targetInternalUpstreamFeedView = $targetInternalUpstreamFeedViews | Where-Object { $_.Name -eq $sourceInternalUpstreamFeedView.Name }
                        
                        $sourceInternalSourceFeed = Get-Feed -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders -FeedId $internalSource.internalUpstreamFeedId
                        $targetInternalSourceFeed = $newTargetFeeds | Where-Object { $_.name -eq $sourceInternalSourceFeed.name }

                        if(($NULL -ne $targetInternalUpstreamFeedView) -and ($NULL -ne $targetInternalSourceFeed)) {
                            $newSource = @{
                                "name"                          = $internalSource.name
                                "protocol"                      = $internalSource.protocol
                                "upstreamSourceType"            = "internal"
                                "internalUpstreamCollectionId"  = $targetInternalUpstreamCollectionId # $internalSource.internalUpstreamCollectionId 
                                "internalUpstreamFeedId"        = $targetInternalSourceFeed.Id
                                "internalUpstreamViewId"        = $targetInternalUpstreamFeedView.id
                                "internalUpstreamProjectId"     = $targetProject.Id
                            }
                            $upstreamSources += $newSource
                        } else {
                            Write-Log -Message "Unable to identify upstream source feed in target.. "
                            Write-Log -Message "Internal Upstream View Id: $internalUpstreamViewId  "
                            Write-Log -Message "Target's Internal Upstream Feed Id $targetSourceFeedId "
                        }
                    } else {
                        $upstreamSources += $internalSource
                    }

                    if($upstreamSources.count -gt 0) {
                        Update-Feed -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -FeedId $existingSourceFeed.Id -UpstreamSources $upstreamSources
                    }
                }
            }
        }


        foreach ($newTargetFeed in $newTargetFeeds) {
            $sourceFeed = $sourceFeeds | Where-Object { $_.Name -eq $newTargetFeed.Name }

            Write-Log -Message '--------------------------------------------------------------------'
            Write-Log -Message "Creating New Packages for Feed [$($newTargetFeed.Name)] in target.. "
            Write-Log -Message '--------------------------------------------------------------------'
            
            $sourceFeedIndexUrl = $sourceFeed._links.packages.href
            $sourceFeedIndexUrl = "https://pkgs.dev.azure.com/$SourceOrgName/$SourceProjectName/_packaging/$($sourceFeed.Name)/nuget/v3/index.json"
            $destinationIndexUrl = "https://pkgs.dev.azure.com/$TargetOrgName/$TargetProjectName/_packaging/$($newTargetFeed.Name)/nuget/v3/index.json"

            $params = @{
                SourceIndexUrl      = $sourceFeedIndexUrl
                SourcePAT           = $SourcePAT
                DestinationIndexUrl = $destinationIndexUrl
                DestinationPAT      = $TargetPAT
                DestinationFeedName = $newTargetFeed.Name
                NumVersions         = $ArtifactFeedPackageVersionLimit
            }

            Move-MyGetNuGetPackages -Verbose @params
        }
    }
}

function Get-OrganizationId {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        try {
             # Get Context user info 
            $url = "https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.0"
            $result1 = Invoke-RestMethod -Method GET -uri $url -Headers $Headers 
            $id = $result1.id

            # Get organizations for user id
            $url = "https://app.vssps.visualstudio.com/_apis/accounts?memberId=$($id)&api-version=7.0"
            $result2 = Invoke-RestMethod -Method GET -uri $url -Headers $Headers 
            $organizations = $result2.value

            foreach($org in $organizations) {
                if($org.accountName -eq $OrgName) {
                    return $org.accountId
                }
            }
        } catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            try { Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR } catch {}
        }
        return $NULL
    }
}


function Get-Feeds {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $projectUrl = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds?api-version=7.0"

        $projectResults = Invoke-RestMethod -Method GET -Uri $projectUrl -Headers $headers

        $orgUrl = "https://feeds.dev.azure.com/$OrgName/_apis/packaging/feeds?api-version=7.0"

        $orgResults = Invoke-RestMethod -Method GET -Uri $orgUrl -Headers $headers
        
        $results = $projectResults.Value + $orgResults.Value
        return $results
    }
}

function Get-Feed {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$FeedId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/Packaging/Feeds/$($FeedId)?api-version=7.0"

        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        return $results
    }
}


function Update-Feed {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$FeedId,

        [Parameter (Mandatory = $TRUE)]
        [AllowEmptyCollection()]
        [Object[]]$UpstreamSources
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url =   "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds/$($FeedId)?api-version=6.1-preview.1"

        $body = @{
            upstreamSources = @() + $UpstreamSources
        } | ConvertTo-Json

        $results = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $body -ContentType "application/json"

        return $results
    }
}


function New-ADOFeed {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [Object]$SourceFeed,

        [Parameter (Mandatory = $TRUE)]
        [AllowEmptyCollection()]
        [Object[]]$UpstreamSources
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        
        $url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds?api-version=7.0"
        # "url"   = $url

        $hideDeletedPackageVersions = $FALSE
        if(($NULL -ne $SourceFeed.hideDeletedPackageVersions) -and ($SourceFeed.hideDeletedPackageVersions -eq $TRUE)) {
            $hideDeletedPackageVersions = $TRUE
        }

        $body = @{
            "name"  = $SourceFeed.name
            "description" = $SourceFeed.description
            "hideDeletedPackageVersions" = $hideDeletedPackageVersions
            "capabilities" = $SourceFeed.capabilities
            upstreamSources = @() + $UpstreamSources
        } | ConvertTo-Json
        
        try {
            Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
        }
        catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
            } catch {}
            return $NULL
        }
    }
}



function Get-Views {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$FeedId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url =  "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/Feeds/$feedId/views?api-version=7.0"

        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        return $results.Value
    }
}


function Update-View {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$FeedId,

        [Parameter (Mandatory = $TRUE)]
        [String]$ViewId,

        [Parameter (Mandatory = $TRUE)]
        [String]$Visibility
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url =   "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/Feeds/$FeedId/views/$($ViewId)?api-version=6.1-preview.1"

        $body = @{
             "visibility" = $Visibility
        } | ConvertTo-Json

        $results = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $body -ContentType "application/json"

        return $results
    }
}


function Get-Packages {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [string]$FeedId
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/Feeds/$($FeedId)/packages?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
        return $results.Value
    }
}

function Start-Command
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandTitle,
        
        [Parameter()]
        $CommandArguments
    )

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $CommandTitle
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.Arguments = $CommandArguments

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    $output = $process.StandardOutput.ReadToEnd();
    $outerror = $process.StandardError.ReadToEnd();

    $process.WaitForExit()

    $return = [pscustomobject]@{
        StdOut = $output
        StdErr = $outerror
        ExitCode = $process.ExitCode
    }

    return $return
}

