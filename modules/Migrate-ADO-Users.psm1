
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

        Write-Log -Message 'Getting ADO Users from Target..'
        $targetUsers = Get-ADOUsers `
            -OrgName $TargetOrgName `
            -PersonalAccessToken $TargetPat

        Write-Log -Message 'Pushing ADO Source Users to Target..'
        Push-ADOUsers `
            -OrgName $TargetOrgName `
            -PersonalAccessToken $TargetPat `
            -Users $sourceUsers `
            -TargetUsers $targetUsers
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
        [Object[]]$Users,

        [Parameter (Mandatory = $TRUE)]
        [Object[]]$TargetUsers
    )
    if ($PSCmdlet.ShouldProcess($OrgName)) {

        Write-Log -Message 'Getting Target ADO Users to verify if users exist already..'

        foreach ($user in $Users) {
            # Check for duplicates
            if ($null -ne ($TargetUsers | Where-Object { $_.PrincipalName -ieq $user.PrincipalName } )) {
                Write-Log -Message "User with PrincipalName [$($user.PrincipalName)] already exists in target org '$OrgName'... "
                continue
            }

            # Add user
            Write-Log -Message ("Add user $($user.DisplayName)")
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

        try{
            $response = az devops user add --email-id $User.PrincipalName --license-type $User.LicenseType --detect $false 2>"$env:temp\err1.txt"
            $ers = Get-Content "$env:temp\err1.txt"
            if ($ers) { Write-Log -Message $ers -LogLevel ERROR }
            Remove-Item -Path "$env:temp\err1.txt"
            
            if ($ForceStakeholderIfNeeded -and !$response) {
                # Lower subscription plan detected
                $newLicense = "stakeholder"
                $response = az devops user add --email-id $User.PrincipalName --license-type $newLicense --detect $false 2>"$env:temp\err2.txt"
                $ers = Get-Content "$env:temp\err2.txt"
                if ($ers) { Write-Log -Message $ers -LogLevel ERROR }
                Remove-Item -Path "$env:temp\err2.txt"

                if ($response) {
                    Write-Log `
                        -Message "User '$($User.DisplayName)' has been demoted from license $($User.LicenseType) to $newLicense because your subscription does not support that license type." `
                        -LogLevel ERROR
                }
            }
            
        } catch {
            Write-Log -Message $_.Exception.Message -LogLevel ERROR
        }
    }
}
