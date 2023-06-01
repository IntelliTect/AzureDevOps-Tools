
Using Module ".\Migrate-ADO-Common.psm1"

function Start-ADOUserMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [String]$SourcePat,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [string]$TargetPat
    )
    if ($PSCmdlet.ShouldProcess(
            "Target org $TargetOrgName",
            "Migrate users from source org $SourceOrgName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-----------------------'
        Write-Log -Message '-- Migrate Org Users --'
        Write-Log -Message '-----------------------'
        Write-Log -Message ' '

        Write-Log -Message 'Getting ADO Users from Source..'
        $sourceUsers = Get-ADOUsers `
            -OrgName $SourceOrgName `
            -PersonalAccessToken $SourcePat

        Write-Log -Message 'Pushing ADO Users to Target..'
        Push-ADOUsers `
            -OrgName $TargetOrgName `
            -PersonalAccessToken $TargetPat `
            -Users $sourceUsers
    }
}

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
            Write-Host ".." -NoNewline
            $members += $UserResponse.members
            $counter += $UserResponse.members.Count
        } while ($counter -lt $totalCount)
        Write-Host " "

        # Convert to ADO User objects
        [ADO_User[]]$users = @()
        foreach ($orgUser in $members ) {
            $users += [ADO_User]::new($orgUser.user.originId, $orgUser.user.principalName, $orgUser.user.displayName, $orgUser.user.mailAddress, $orgUser.accessLevel.accountLicenseType)
        }

        return $users
    }
}

function Push-ADOUsers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [ADO_User[]]$Users
    )
    if ($PSCmdlet.ShouldProcess($OrgName)) {

        Write-Log -Message 'Getting Target ADO Users to verify if users exist already..'
        [ADO_User[]]$targetUsers = Get-ADOUsers `
            -OrgName $OrgName `
            -PersonalAccessToken $PersonalAccessToken

        foreach ($user in $Users) {
            # Check for duplicates
            if ($null -ne ($targetUsers | Where-Object { $_.PrincipalName -ieq $user.PrincipalName } )) {
                Write-Log -Message "User with PrincipalName [$($user.PrincipalName)] already exists in target org '$OrgName'... "
                continue
            }

            # Add user
            Write-Log -Message "Add user $($User.DisplayName)"
            Add-ADOUser `
                -OrgName $OrgName `
                -PersonalAccessToken $PersonalAccessToken `
                -User $user `
                -ForceStakeholderIfNeeded
        }
    }
}

function Add-ADOUser {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [String]$PersonalAccessToken,

        [Parameter (Mandatory = $TRUE)]
        [ADO_User]$User,

        # For testing or migrations to orgs with lower subscription plans
        [Parameter (Mandatory = $FALSE)]
        [Switch]$ForceStakeholderIfNeeded
    )
    if ($PSCmdlet.ShouldProcess($OrgName, "Add ADO user $User")) {
        Set-AzDevOpsContext `
            -PersonalAccessToken $PersonalAccessToken `
            -OrgName $OrgName

        $response = az devops user add --email-id $User.PrincipalName --license-type $User.LicenseType --detect $false

        if ($ForceStakeholderIfNeeded -and !$response) {
            # Lower subscription plan detected
            $newLicense = "stakeholder"
            $response = az devops user add --email-id $User.PrincipalName --license-type $newLicense --detect $false
            if ($response) {
                Write-Log `
                    -Message "User '$($User.DisplayName)' has been demoted from license $($User.LicenseType) to $newLicense because your subscription does not support that license type." `
                    -LogLevel ERROR
            }
        }
    }
}
