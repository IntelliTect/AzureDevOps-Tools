
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
        [String]$ProjectPath
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
            
            $resultFeed = New-ADOFeed -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -FeedName $feed.Name -UpstreamSources $feed.upstreamSources
           
            if ($null -eq $resultFeed) {
                Write-Log -Message "Could not create a new feed with name '$($FeedName)'. The feed name may be reserved by the system." -LogLevel ERROR
               continue
            } else {
                Write-Log -Message "Done!" -LogLevel SUCCESS
                $newTargetFeeds += $resultFeed
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
            }

            Move-MyGetNuGetPackages -Verbose @params

            Write-Log -Message ' '
        }
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
        $url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds?api-version=7.0"

        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        return $results.Value
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
        [String]$FeedName,

        [Parameter (Mandatory = $TRUE)]
        [Object[]]$UpstreamSources
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        
        $url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds?api-version=7.0"

        $body = @{
            "name"  =$FeedName
            "url"   = $url
            upstreamSources = @() + $UpstreamSources
        } | ConvertTo-Json
        
        try {
            $result = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
            return $result
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

