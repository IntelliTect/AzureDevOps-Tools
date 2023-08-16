[Flags()] enum LogLevel {
    DEBUG = 0
    INFO
    SUCCESS
    WARNING
    ERROR
}


class ADO_Team {
    [String]$Id
    [String]$Name
    [String]$Description
    
    ADO_Team(
        [String]$id,
        [String]$name,
        [String]$description
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.Description = $description
    }
}

class ADO_User {
    [String]$Id
    [String]$OriginId
    [String]$PrincipalName
    [String]$DisplayName
    [String]$MailAddress
    [String]$LicenseType
    
    ADO_User(
        [String]$id,
        [String]$originId,
        [String]$principalName,
        [String]$displayName,
        [String]$mailAddress,
        [String]$licenseType
    ) {
        $this.Id = $id
        $this.OriginId = $originId
        $this.PrincipalName = $principalName
        $this.DisplayName = $displayName
        $this.MailAddress = $mailAddress
        $this.LicenseType = $licenseType
    }
}

class ADO_Group {
    [String]$Id
    [String]$Name
    [String]$PrincipalName
    [String]$Description
    [String]$Descriptor
    [ADO_GroupMember[]]$UserMembers = @()
    [ADO_Group[]]$GroupMembers = @()
    
    ADO_Group(
        [String]$id,
        [String]$name,
        [String]$principalName,
        [String]$description,
        [String]$descriptor
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.PrincipalName = $principalName
        $this.Description = $description
        $this.Descriptor = $descriptor
    }
}

class ADO_GroupMember {
    [String]$Id
    [String]$Name
    [String]$PrincipalName
    
    ADO_GroupMember(
        [String]$id,
        [String]$name,
        [String]$principalName
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.PrincipalName = $principalName
    }
}


function New-HTTPHeaders {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken
    )
    if ($PSCmdlet.ShouldProcess('DevOps PAT', 'Return basic auth HTTP headers')) {
        $authToken = [System.Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes([string]::Format("{0}:{1}", "", $PersonalAccessToken)))
        $headers = @{'Authorization' = "Basic $authToken" }
        return $headers
    }
}

# Log in & set context with the 
# Azure Devops CLI
function Set-AzDevOpsContext {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $FALSE)]
        [String]$ProjectName = ''
    )
    if ($PSCmdlet.ShouldProcess('DevOps PAT', 'Set DevOps environment variable')) {
        $Env:AZURE_DEVOPS_EXT_PAT = $PersonalAccessToken
        az devops configure --defaults "project=$ProjectName" "organization=https://dev.azure.com/$OrgName"
    }
}

function Write-Log {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$Message,

        [Parameter (Mandatory = $FALSE)]
        [LogLevel]$LogLevel = [LogLevel]::INFO,

        [Parameter (Mandatory = $FALSE)]
        [String]$LogPath = ($env:MIGRATION_LOGS_PATH)
    )
    if ($PSCmdlet.ShouldProcess("[$LogLevel]: $Message")) {
        [System.ConsoleColor]$color = [System.ConsoleColor]::White
        $Message = "[$LogLevel]: $Message"
    
        switch ($LogLevel) {
            [LogLevel]::DEBUG {
                $color = [System.ConsoleColor]::Gray
            }
            [LogLevel]::SUCCESS {
                $color = [System.ConsoleColor]::Green
            }
            [LogLevel]::WARNING {
                $color = [System.ConsoleColor]::Yellow
            }
            [LogLevel]::ERROR {
                $color = [System.ConsoleColor]::Red
            }
        }
    
        Write-Host $Message -ForegroundColor $color
    
        if ($LogPath) {
            Write-LogAsync `
                -Text $Message `
                -Level $LogLevel `
                -LogPath "$LogPath\logs\migration-$($LogLevel.ToString().ToLower()).log" `
                -UseMutex
            Write-LogAsync `
                -Text $Message `
                -Level $LogLevel `
                -LogPath "$LogPath\logs\migration.log" `
                -UseMutex
        }
    }
}

function Write-LogAsync {
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $TRUE)]
        [String]$Text,

        [Parameter(Mandatory = $TRUE)]
        [LogLevel]$Level,

        [Parameter(Mandatory = $TRUE)]
        [string]$LogPath,

        [Parameter(Position = 3)]
        [Switch]$UseMutex
    )
    if ($PSCmdlet.ShouldProcess($LogPath, "Log '$Message' to")) {
        Write-Verbose "Log:  $LogPath"
        [String]$date = (get-date).ToString()
        if (Test-Path $LogPath) {
            if ((Get-Item $LogPath).length -gt 5mb) {
                $filenamedate = get-date -Format 'MM-dd-yy hh.mm.ss'
                $archivelog = ("$LogPath.$filenamedate.archive").Replace('/', '-')
                copy-item $LogPath -Destination $archivelog
                Remove-Item $LogPath -force
                Write-Verbose 'Rolled the log.'
            }
        }
        else {
            New-Item -Path $LogPath -ItemType File -Force
        }

        $line = "[$date] [$Level] $text"
        if ($UseMutex) {
            $logMutex = New-Object System.Threading.Mutex($false, 'LogMutex')
            $logMutex.WaitOne() | out-null
        
            $line | out-file -FilePath $LogPath -Append
            $logMutex.ReleaseMutex() | out-null
        }
        else {
            $line | out-file -FilePath $LogPath -Append
        }
    }
}

function ConvertTo-Object {
    begin { $object = New-Object Object }
    
    process {
    
        $_.GetEnumerator() | ForEach-Object { Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value }  
    
    }
    
    end { $object }
}

function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
 
    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }
 
        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )
 
            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            ## If the object has properties that need enumeration
            ## Convert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        }
        else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}

function Get-ProjectFolderPath {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$RunDate,
        
        [Parameter (Mandatory = $FALSE)]
        [String]$SourceProject,
        
        [Parameter (Mandatory = $FALSE)]
        [String]$TargetProject,

        [Parameter (Mandatory = $TRUE)]
        [String]$Root
    )
    if ($PSCmdlet.ShouldProcess("[$LogLevel]: $Message")) {
        if (!$SourceProject -or !$TargetProject) {
            return "$Root\Projects\$RunDate\OrgMigrationLogs"
        }
        return "$Root\Projects\$RunDate\$SourceProject-to-$TargetProject"
    }
}

function Set-ProjectFolders {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$RunDate,

        [Parameter (Mandatory = $TRUE)]
        [Object[]]$Projects,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrg,

        [Parameter (Mandatory = $TRUE)]
        [String]$SourcePAT,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrg,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetPAT,

        [Parameter (Mandatory = $TRUE)]
        [String]$SavedAzureQuery,

        [Parameter (Mandatory = $TRUE)]
        [String]$MSConfigPath,

        [Parameter (Mandatory = $TRUE)]
        [String]$Root
    )

    foreach ($project in $Projects) {
        Write-Log -Message "Setting up workspace for migration $($Project.SourceProject) --> $($Project.TargetProject)"

        # Configure the JSON file (for migrating work items)
        $baseJson = Get-Content -path $MSConfigPath | Out-String | ConvertFrom-Json
        $baseJson.'source-connection'.'account' = "https://dev.azure.com/$SourceOrg"
        $baseJson.'source-connection'.'project' = $Project.SourceProject
        $baseJson.'source-connection'.'access-token' = $SourcePAT

        $baseJson.'target-connection'.'account' = "https://dev.azure.com/$TargetOrg"
        $baseJson.'target-connection'.'project' = $Project.TargetProject
        $baseJson.'target-connection'.'access-token' = $TargetPAT

        $baseJson.'query' = $SavedAzureQuery
    
        # Create the project folder
        $ProjectFolder = Get-ProjectFolderPath `
            -RunDate $RunDate `
            -SourceProject $Project.SourceProject `
            -TargetProject $Project.TargetProject `
            -Root $Root

        New-Item -ItemType Directory -Force -Path $ProjectFolder
        $baseJson | ConvertTo-Json -depth 100 | Out-File "$($ProjectFolder)\ProjectConfiguration.json" -Force
    }

    Write-Log -Message '-------------------------- Done creating Directories --------------------------' -LogLevel DEBUG
}


# Users

function Get-ADOUsers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,
        
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken
    )
    if ($PSCmdlet.ShouldProcess($OrgName)) {
        Set-AzDevOpsContext -PersonalAccessToken $PersonalAccessToken -OrgName $OrgName

        Write-Host "Calling az devops user list.." -NoNewline
        $results = az devops user list --detect $False | ConvertFrom-Json

        $members = $results.members
        $totalCount = $results.totalCount
        $counter = $members.Count
        do {
            $UserResponse = az devops user list --detect $False --skip $counter | ConvertFrom-Json
            Write-Host "." -NoNewline
            $members += $UserResponse.members
            $counter += $UserResponse.members.Count
        } while ($counter -lt $totalCount)
        Write-Host " "

        # Convert to ADO User objects
        [ADO_User[]]$users = @()
        foreach ($orgUser in $members ) {
            $users += [ADO_User]::new($orgUser.Id, $orgUser.user.originId, $orgUser.user.principalName, $orgUser.user.displayName, $orgUser.user.mailAddress, $orgUser.accessLevel.accountLicenseType)
        }

        return $users
    }
}

function Get-ADOUsersByAPI {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($OrgName)) {
        
        $url = "https://vssps.dev.azure.com/$OrgName/_apis/graph/users?api-version=7.0-preview.1"
           
        $members = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        # Convert to ADO User objects
        [ADO_User[]]$users = @()
        foreach ($orgUser in $members.Value ) {
            $users += [ADO_User]::new($orgUser.Id, $orgUser.originId, $orgUser.principalName, $orgUser.displayName, $orgUser.mailAddress, "")
        }

        return $users
    }
}

# ADO Groups
function Get-ADOGroups {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $FALSE)]
        [String]$GroupDisplayName,

        [Parameter (Mandatory = $FALSE)]
        [Bool]$GetGroupMembers = $TRUE
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        $organization = "https://dev.azure.com/$OrgName/"
        if ($GroupDisplayName) {
            $groups = az devops security group list --query "graphGroups[?displayName == '$($GroupDisplayName)']" --organization $organization --project $ProjectName --detect $false | ConvertFrom-Json
            if (!$groups) {
                throw "Group called '$GroupDisplayName' cannot be found in '$OrgName/$ProjectName'"
            }
        }
        else {
            $groups = (az devops security group list --organization $organization --project $ProjectName --detect $false --subject-types vssgp | ConvertFrom-Json).graphGroups
        }
       
        [ADO_Group[]]$groupsFound = @() 
        foreach ($group in $groups) {
            Write-Host "." -NoNewline
            $group = [ADO_Group]::new($group.originId, $group.displayName, $group.principalName, $group.description, $group.descriptor)

            if ($GetGroupMembers -eq $TRUE) { 
                $members = Get-ADOGroupMembers `
                    -OrgName $OrgName `
                    -ProjectName $ProjectName `
                    -PersonalAccessToken $PersonalAccessToken `
                    -GroupDescriptor $group.Descriptor

                $group.GroupMembers = $members.GroupGroupMembers
                $group.UserMembers = $members.GroupUserMembers
            }
            
            $groupsFound += $group
        }
        Write-Host "."
        return $groupsFound
    }
}

function Get-ADOGroupMembers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [String]$GroupDescriptor
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        [ADO_GroupMember[]]$GroupUserMembers = @()
        [ADO_Group[]]$GroupGroupMembers = @()

        $organization = "https://dev.azure.com/$OrgName/"
        try {
            $members = az devops security group membership list --id $GroupDescriptor --organization $organization --detect $false | ConvertFrom-Json
        } catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
            } catch {}
        }

        if ($members) {
            $descriptors = $members | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
    
            foreach ($descriptor in $descriptors) {
                Write-Host "." -NoNewline
                $member = $members.$descriptor
                if ($member.subjectKind -eq "user") {
                    $GroupUserMembers += [ADO_GroupMember]::new($member.originId, $member.displayName, $member.principalName)
                }
                else {
                    $GroupGroupMembers += [ADO_Group]::new($member.originId, $member.displayName, $member.principalName, $member.description, $member.descriptor)
                }
            }
        }

        return @{
            "GroupUserMembers"  = $GroupUserMembers
            "GroupGroupMembers" = $GroupGroupMembers
        }
    }
}



# Projects
function Get-ADOProjects {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $FALSE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        if ($ProjectName) {
            $url = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName"
            return Invoke-RestMethod -Method Get -uri $url -Headers $Headers
        }
        else {
            $url = "https://dev.azure.com/$OrgName/_apis/projects?`$top=600&api-version=5.1"
            $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
            return $results.value
        }
    }
}

function Get-ADOProjectTeams {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $FALSE)]
        [String]$TeamDisplayName
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        $url = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName/teams?api-version=6.0"
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        [ADO_Team[]]$teams = @()
        foreach ($result in $results.value) {
            $teams += [ADO_Team]::new($result.id, $result.name, $result.description)
        }

        if ($TeamDisplayName) {
            return $teams | Where-Object { $_.Name -eq $TeamDisplayName }
        }
        return $teams
    }
}


# Pipelines
function Get-Pipelines {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [String]$RepoId = $NULL
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions?api-version=7.0"
        if ($RepoId) {
            $url = "https://dev.azure.com//$OrgName/$ProjectName/_apis/build/definitions?repositoryId=$RepoId&repositoryType=TfsGit";
        }
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results.value
    }
}

function Get-Pipeline {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [String]$DefinitionId = $NULL
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions/$($DefinitionId)?api-version=7.0";

        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results
    }
}


#Repos

function Get-Repos([string]$projectName, [string]$orgName, $headers) {
    $url = "https://dev.azure.com/$orgName/$projectName/_apis/git/repositories?api-version=7.0"

    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    if ($ProcessName) {
        return $results.value | Where-Object { $_.name -ieq $ProcessName }
    }
    else {
        return , $results.value
    }
}

function Get-Repo([string]$projectName, [string]$orgName, $headers, $repoId) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/git/repositories/$repoId"
    
    $results =  Invoke-RestMethod -Method Get -uri $url -Headers $headers

    return , $results
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
