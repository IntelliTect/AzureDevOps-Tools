<#
    .SYNOPSIS
        Migrate NuGet Packages From MyGet to Azure DevOps

    .DESCRIPTION
        This function copies all NuGet packages from a MyGet.org public feed
        to an Azure DevOps project feed. This requires a password from your
        Azure DevOps organization. Passowrd can be in the form of a PAT (Personal Access Token)

    .PARAMETER SourceIndexUrl
        The Index URL from your MyGet Package feed.

    .PARAMETER DestinationIndexUrl
        The Index URL of your Azure DevOps feed.

    .PARAMETER DestinationPAT
        Azure DevOps Personal Access Token (PAT) string

    .PARAMETER TempFilePath
        A file path where a .nupkg will be created during migration. 
        This is automatically cleaned up.
    
    .PARAMETER SourceUsername
        The username of your Source pacakgeing provider

    .PARAMETER SourcePassword
        A string password to your package source. Password is encrypted before 
        being used in any webrequests.

    .PARAMETER NumVersions
        Max number of versions to migrate

    .EXAMPLE
        # Create a Hashtable to splat to your 'Move-MyGetNuGetPackages'
        $params = @{
            SourceIndexUrl      = 'https://www.myget.org/F/mytestfeed/api/v3/index.json'
            DestinationIndexUrl = 'https://pkgs.dev.azure.com/mytestorg/_packaging/mynewtestfeed/nuget/v3/index.json'
            DestinationPassword = 'thisisafakepassword'
            TempFilePath        = 'C:/Temp/'
            FeedName            = 'mynewtestfeed'
        }

        Move-MyGetNuGetPackages @params

    .NOTES
        For more information on Personal Access Tokens - https://docs.microsoft.com/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate
#>
function Move-MyGetNuGetPackages
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceIndexUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationIndexUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $SourcePAT,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationPAT,

        [Parameter()]
        [string]
        $TempFilePath = $env:Temp,

        [Parameter()]
        [string]
        $SourceUsername,

        [Parameter()]
        [securestring]
        $SourcePassword,

        [Parameter()]
        [string]
        $DestinationFeedName,

        [Parameter()]
        [int]
        $NumVersions = -1
    )

    Write-Log -Message "Migrate Package Versions for Feed [$($DestinationFeedName)] in target.. " -LogLevel INFO

    if ($null -eq $TempFilePath)
    {
        $TempFilePath = [System.IO.Path]::GetTempPath()

        if ($null -eq $TempFilePath)
        {
            Write-Log -Message "Temp filepath not found. Please provide value for -TempFilePath" -LogLevel ERROR
            throw
        }
    }

    if ($Verbose)
    {
        $oldVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'
    }

    if ($DestinationFeedName)
    {
        # Adds Azure DevOps feed to NuGet sources/ update password to access feed. 
        # It also prevent's further progress if NuGet is not set up correctly for migration on the users machine.
        Update-NuGetSource -FeedName $DestinationFeedName -DevOpsSourceUrl $DestinationIndexUrl -Password $DestinationPAT
    }

    if ($SourcePassword)
    {
        $sourceCredential = New-Object -TypeName pscredential -ArgumentList $SourceUsername, $SourcePassword
    }
    else
    {
        $PAT = $DestinationPAT
        if($NULL -ne $SourcePAT) { $PAT = $SourcePAT }
        $sourceSecurePassword = ConvertTo-SecureString -String $PAT  -AsPlainText -Force
        $sourceCredential = New-Object -TypeName pscredential -ArgumentList 'PackageMigration', $sourceSecurePassword
    }

    $destinationSecurePassword = ConvertTo-SecureString -String $DestinationPAT -AsPlainText -Force
    $destinationCredential = New-Object -TypeName pscredential -ArgumentList 'PackageMigration', $destinationSecurePassword

    # Collects and compares packages from source to Azure DevOps feed
    $sourceVersions = Get-ContentUrls -IndexUrl $SourceIndexUrl -Credential $sourceCredential
    if($NULL -eq $sourceVersions) {
        Write-Log -Message "Found no package versions in source.."
        return $NULL
    }


    $destinationVersions = Get-Packages -IndexUrl $DestinationIndexUrl -Credential $destinationCredential
    $versionsMissingInDestination = $NULL 
    if($NULL -ne $sourceVersions) {
        $versionsMissingInDestination = Get-MissingVersions -SourceVersions $sourceVersions -DestinationVersions $destinationVersions
    }

    Write-Log -Message "Found $($sourceVersions.Count) package versions in source, $($destinationVersions.Count) package versions in destination, and $($versionsMissingInDestination.Count) packages versions need to be copied"

    if ($NumVersions -gt -1 -and $NumVersions -lt $versionsMissingInDestination.Length)
    {
        # $versionsMissingInDestination = $versionsMissingInDestination | Select-Object -First $NumVersions
        Write-Log -Message "Only the First $($NumVersions) package versions will be copied!"
        $numVersionPackages = [System.Collections.ArrayList]@()
        $previousName = ""
        $counter = 0
        foreach ($sourceVersion in $SourceVersions)
        {   
            $name = "$($sourceVersion.Name)"
            if($name -ne $previousName) {
                $previousName = $name
                $counter = 0
            }

            if($counter -ge $NumVersions) {
                continue
            } 
            
            $null = $numVersionPackages.Add($sourceVersion);
            $counter += 1
        }
        $versionsMissingInDestination = $numVersionPackages
    }

    if ($versionsMissingInDestination.Length -gt 0) {
        Write-Log -Message "Migrating $($versionsMissingInDestination.Count) package versions."

        # Migrates packages from sources to Azure DevOps feed
        $versionContentUrls = $versionsMissingInDestination.Url
        $results = Start-MigrationSingleThreaded -ContentUrls $versionContentUrls -DestinationIndexUrl $DestinationIndexUrl -TempFilePath $TempFilePath -SourceCredential $sourceCredential

        Out-Results $results
    }
    $VerbosePreference = $oldVerbosePreference

    return $results
}

<#
    .SYNOPSIS
        Returns the NuGet connection URLs

    .PARAMETER IndexUrl
        The Index URL from your MyGet Package feed.

    .PARAMETER Credential
        The credential object to connect to packaging source.
#>
function Get-ContentUrls
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $IndexUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential
    )

    # Var is used to ensure there aren't multiple requests to package urls
    $Script:registrationRequests = [System.Collections.ArrayList]::new()
    $packages = (Get-Packages -IndexUrl $IndexUrl -Credential $Credential).id | Select-Object -Unique

    $registrationBaseUrl = Get-RegistrationBase -IndexUrl $IndexUrl -Credential $Credential
    $result = [System.Collections.ArrayList]::new()

    # Collect source package URLs to migrate
    foreach ($packageName in $packages)
    {
        $registrationUrl = "$registrationBaseUrl/$packageName/index.json"
        $versions = Read-CatalogUrl -RegistrationUrl $registrationUrl -Credential $Credential

        $null = $result.AddRange($versions)
    }

    return $result
}

<#
    .SYNOPSIS
        Filters and returns the NuGet v3 URL

    .PARAMETER IndexUrl
        The Index URL from your MyGet Package feed.

    .PARAMETER Credential
        The credential object to connect to packaging source.
#>
function Get-V3SearchBaseURL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $IndexUrl,

        [Parameter()]
        [pscredential]
        $Credential
    )

    $indexJson = Get-Index -IndexUrl $IndexUrl -Credential $Credential
    $entry = ($indexJson | Where-Object -FilterScript {$_.'@type' -match 'SearchQueryService.*'})[0]

    return $entry.'@id'
}

<#
    .SYNOPSIS
        This is an empty function right now for future development.

    .PARAMETER IndexUrl
        The Index URL from your desired Package feed.
#>
function Get-V3FlatBaseURL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $IndexUrl
    )
}

<#
.SYNOPSIS
    Returns the base registration URL

.PARAMETER IndexUrl
    The Index URL from the desired Package feed.

.PARAMETER Credential
        The credential object to connect to packaging source.
#>
function Get-RegistrationBase
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $IndexUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential
    )

    $indexJson = Get-Index -IndexUrl $IndexUrl -Credential $Credential
    $entry = $entry = ($indexJson | Where-Object -FilterScript {$_.'@type' -eq 'RegistrationsBaseUrl/Versioned'})[0]

    return $entry.'@id'
}

<#
    .SYNOPSIS
        Returns the resources for different NuGet services

    .PARAMETER IndexUrl
        The Index URL from your desired Package feed.

    .PARAMETER Credential
        The Credential object to access a URL
#>
function Get-Index
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $IndexUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential
    )

    return (Invoke-RestMethod -Uri $IndexUrl -Credential $Credential).resources
}

<#
    .SYNOPSIS
        Returns package information from the desired source

    .PARAMETER IndexUrl
        Base Url to query from.

    .PARAMETER Credential
        Credential to access base URL where packages are stored.

    .PARAMETER Take
        Identifies packages in a query
#>
function Get-Packages
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $IndexUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential,

        [Parameter()]
        [int]
        $Take = 100
    )

    $searchBaseUrl = Get-V3SearchBaseURL -IndexUrl $IndexUrl -Credential $Credential
    $result = [System.Collections.ArrayList]::new()
    $i = 0

    # Create the body of the query
    $payLoad = [ordered]@{
        Prerelease = $true
        SemverLevel = '2.0'
        Skip = 0
        Take = $Take
    }

    While ($true)
    {
        # Adjust the skip portion of the query to get all packages associated with URL
        $payLoad.Skip = $i * $Take
        Write-Log -Message "Request: $searchBaseUrl, Prerelease = $($payload.Prerelease), SemverLevel = $($payload.SemverLevel), Skip =$($payload.Skip), Take = $($payload.Take)"
        try
        {
            $response = Invoke-RestMethod -Uri $searchBaseUrl -Body $payLoad -Credential $Credential
            $packages = $response.data
            if ($packages.Count -eq 0)
            {
                break
            }

            foreach ($package in $packages)
            {
                foreach ($version in $package.versions)
                {
                    $packageObject = [PSCustomObject]@{
                        Id      = $package.id
                        Version = $version.version
                    }
                    if ($result -notcontains $packageObject) {
                        $null = $result.add($packageObject)
                    }
                }
            }

            $i++
        }
        catch
        {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message "Exception: $($_.Exception)" -LogLevel ERROR
            try {
                Write-Log -Message "Exception Message: $(($_ | ConvertFrom-Json).message)" -LogLevel ERROR
            } catch {}
            
            break
        }
    }

    return $result
}

<#
    .SYNOPSIS
        Reads a catalog of packages

    .PARAMETER RegistrationUrl
        The base registration URL to query with.

    .PARAMETER Credential
        The credential object to connect to packaging source.
#>
function Read-CatalogUrl
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $RegistrationUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential
    )

    $result = [System.Collections.ArrayList]::new()

    if ($RegistrationUrl -in $Script:registrationRequests)
    {
        Write-Log -Message "Skipping duplicate request to $RegistrationUrl" -LogLevel WARNING
    }
    else
    {
        Write-Log -Message "Request: $RegistrationUrl" -LogLevel INFO

        $response = Invoke-RestMethod -Uri $RegistrationUrl -Credential $Credential

        # Adds to track Registration requests to identify duplicate requests
        $null = $Script:registrationRequests.Add($RegistrationUrl)
        foreach ($item in $response.items)
        {
            $null = $result.AddRange((Read-CatalogEntry -Item $item -Credential $Credential))
        }

        Write-Output -NoEnumerate $result
    }
}

<#
    .SYNOPSIS
        Returns a pacakge entry.

    .DESCRIPTION
        This is a recursive function to reach the catalog
        entries of a given Catalog URL.

    .PARAMETER Item
        The package entry from the parent catalog
#>
function Read-CatalogEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Item,
	
	[Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential
    )

    $result = [System.Collections.ArrayList]::new()
    $itemType = $Item.'@type'

    if ($itemType -eq 'catalog:CatalogPage' -and $null -eq $item.items)
    {
        $catalogUrl = $Item.'@id'
        $null = $result.AddRange((Read-CatalogUrl -RegistrationUrl $catalogUrl -Credential $Credential))
    }
    elseif ($itemType -eq 'catalog:CatalogPage')
    {
        foreach ($subItem in $Item.items)
        {
            $null = $result.AddRange((Read-CatalogEntry -Item $subItem -Credential $Credential))
        }
    }
    elseif ($itemType -eq 'Package')
    {
        $returnItem = [PSCustomObject]@{
            Name    = $Item.catalogEntry.id
            Version = $Item.catalogEntry.version
            Url     = $Item.packageContent
        }

        $null = $result.Add($returnItem)
    }

    Write-Output -NoEnumerate $result
}

<#
    .SYNOPSIS
        Migrates packages using NuGet.exe

    .DESCRIPTION
        This function migrates packages one at a time.
        In future development, there will be an option to use multi-threading 
        to migrate packages faster.

    .PARAMETER ContentUrls
        URL's of migrating packages

    .PARAMETER DestinationIndexUrl
        Destination index URL where packages are migrating to.

    .PARAMETER TempFilePath
        The local folder path for temporary NuGet packages during migration.

    .PARAMETER SourceCredential
        The credential object to connect to the source packaging repository.
#>
function Start-MigrationSingleThreaded
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $ContentUrls,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationIndexUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $TempFilePath,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $SourceCredential
    )

    $results = [System.Collections.ArrayList]::new()
    $TempFilePath = "$TempFilePath\temp.nupkg"

    foreach ($url in $ContentUrls)
    {
        $result = Start-Migration -ContentUrl $url -DestinationIndexUrl $DestinationIndexUrl -TempFilePath $TempFilePath -Credential $SourceCredential
        Out-Result @result
        $null = $results.Add($result)
    }

    # Clean up temp .nupkg file created during migration.
    Remove-Item -Path $TempFilePath -Force
    return $results
}

<#
    .SYNOPSIS
        Uses NuGet.exe to migrate packages from source to destination.

    .PARAMETER ContentUrl
        URL of the package to migrate.

    .PARAMETER DestinationIndexUrl
        Destination index URL where package is migrating to.
    
    .PARAMETER Credential
        The credential object to connect to packaging source.

    .PARAMETER TempFilePath
        The local folder path for temporary NuGet packages during migration.
#>
function Start-Migration
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ContentUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationIndexUrl,

        [Parameter()]
        [AllowNull()]
        [pscredential]
        $Credential,

        [Parameter()]
        [string]
        $TempFilePath
    )
    
    try
    {
        $response = Invoke-WebRequest -Uri $ContentUrl -Credential $Credential
    }
    catch
    {
        $return = @{
            Url         = $ContentUrl
            HttpStatus  = -1
            NuGetStatus = -1
            Stdout      = $null
        }

        return $return
    }

    if ($response.StatusCode -ne 200)
    {
        $return = @{
            Url         = $ContentUrl
            HttpStatus  = $response.StatusCode
            NuGetStatus = -1
            Stdout      = $null
        }

        return $return
    }
    
    # Writes package content bytes to temporary .nupkg file during migration
    [io.file]::WriteAllBytes($TempFilePath, $response.Content)
    $arguments = "push -Source $DestinationIndexUrl -ApiKey Migration $TempFilePath -SkipDuplicate"

    $location = Get-Location
    $exepath = "$location\nuget.exe"

    $result = Start-Command -CommandTitle $exepath -CommandArguments $arguments

    $return = @{
        Url         = $ContentUrl
        HttpStatus  = $response.StatusCode
        NuGetStatus = $result.ExitCode
        StdOut      = $result.StdOut
        StdErr      = $result.StdErr
    }

    return $return
}

<#
    .SYNOPSIS
        Writes the result of individual package migrations.

    .PARAMETER Url
        Url of the migrating package

    .PARAMETER HttpsStatus
        Http Status code returned from web request.

    .PARAMETER NugetStatus
        NuGet migration status code

    .PARAMETER StdOut
        Standard Output

    .PARAMETER StdErr
        Standard Error Output
#>
function Out-Result
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Url,

        [Parameter()]
        [string]
        $HttpStatus,

        [Parameter()]
        [string]
        $NugetStatus,

        [Parameter()]
        [string]
        $StdOut,

        [Parameter()]
        [string]
        $StdErr
    )

    $level = "INFO"
    if($NugetStatus -ne 0) {
        $level = "WARNING"
    }

    Write-Log -Message "Url: $Url, --> fetchContent HttpStatus: $HttpStatus, publish NugetStatus: $NugetStatus" -LogLevel $level

    if ($StdOut)
    {
        Write-Log -Message "StdOut Message: $StdOut" -LogLevel $level
    }

    if ($StdErr)
    {
        Write-Log -Message "StdErr Message: $StdErr" -LogLevel ERROR
    }
}

<#
    .SYNOPSIS
        Writes the results of package migration process as a whole.

    .PARAMETER Results
        Results of the package migration
#>
function Out-Results
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Results
    )

    $errors = $Results | Where-Object -FilterScript {$_.HttpStatus -ne 200 -or $_.NuGetStatus -ne 0}
    $pushedCount = $Results.Count - $errors.Count

    Write-Log -Message "Package Count: $($pushedCount) packages pushed successfully"
    if ($errors.Count -gt 0)
    {
        Write-Log -Message "Error Count: $($errors.Count) errors." -LogLevel WARNING
    }
}

<#
    .SYNOPSIS
        Returns package ID's from the source not located in the destination.

    .PARAMETER SourceVersions
        Source pacakges to be filtered

    .PARAMETER DestinationVersions
        Destination packages to be filtered against.
#>
function Get-MissingVersions
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $SourceVersions,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DestinationVersions
    )

    $missingPackages = [System.Collections.ArrayList]@()
    try {
        # hashtable of name____id for fast lookup.  Powershell hashtables are not case sensitive.
        $destHash = @{}
        $sep = "_____"

        foreach ($DestinationVersion in $DestinationVersions) {
            $dKey = "$($DestinationVersion.Id)$sep$($DestinationVersion.Version)"
            if (-not $destHash.ContainsKey($dKey))
            {
                $destHash.Add($dKey, $null)
            }
        }

        foreach ($sourceVersion in $SourceVersions)
        {
            $sKey = "$($sourceVersion.Name)$sep$($sourceVersion.Version)"
            if (-not $destHash.ContainsKey($sKey))
            {
                $null = $missingPackages.Add($sourceVersion);
            }
        }
    }catch
    {
        Write-Log -Message "FAILED!" -LogLevel ERROR
        Write-Log -Message "Exception: $($_.Exception)" -LogLevel ERROR
        try {
            Write-Log -Message "Exception Message: $(($_ | ConvertFrom-Json).message)" -LogLevel ERROR
        } catch {}
        
        break
    }

    return $missingPackages;
}

<#
    .SYNOPSIS
        Runs NeGet using .Net to get all required information.

    .PARAMETER CommandTitle
        The .exe to run

    .PARAMETER CommandArguments
        Argument string to run with specified .exe
#>
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

    $stdOutput = $process.StandardOutput.ReadToEnd();
    $stdError = $process.StandardError.ReadToEnd();

    $process.WaitForExit()

    $return = [pscustomobject]@{
        StdOut = $stdOutput
        StdErr = $stdError
        ExitCode = $process.ExitCode
    }

    return $return
}

<#
    .SYNOPSIS
        Updates NuGet config file to access Azure Artifacts feed

    .PARAMETER FeedName
        Azure Artifact feed name

    .PARAMETER DevOpsSourceUrl
        Azure DevOps feed source index Url

    .PARAMETER Password
        PAT to connect to Azure DevOps Feed
#>
function Update-NuGetSource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $FeedName,

        [Parameter(Mandatory = $true)]
        [string]
        $DevOpsSourceUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Password
    )

    $location = Get-Location
    $exepath = "$location\nuget.exe"

    $sourceAdd = Start-Command -CommandTitle $exepath -CommandArguments "sources Add -Name $FeedName -Source $DevOpsSourceUrl"
    if ($sourceAdd.ExitCode -eq 1)
    {
        # If Feed already contains the package just output a warning else output the error
        if ($sourceAdd.StdErr -match ".*name specified has already been added to the list of available package sources.*")
        {
            Write-Log -Message "Message: $($sourceAdd.StdErr)" -LogLevel WARNING
        }
        else
        {
            Write-Log -Message "Message: $($sourceAdd.StdErr)" -LogLevel ERROR
            throw
        }
    }

    $sourceUpdate = Start-Command -CommandTitle $exepath -CommandArguments "sources Update -Name $FeedName -UserName 'username' -Password $password"

    if ($sourceUpdate.ExitCode -eq 1)
    {
        Write-Log -Message "Message: $($sourceUpdate.StdErr)" -LogLevel ERROR
        throw
    }
}

Export-ModuleMember -Function 'Move-MyGetNuGetPackages'