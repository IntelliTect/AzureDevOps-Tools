
function Start-ADOPoliciesMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Policies from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-----------------------'
        Write-Log -Message '-- Migrate Policies --'
        Write-Log -Message '----------------------'
        Write-Log -Message ' '

        $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders
        $policies = Get-Policies -ProjectName $SourceProjectName -orgName $SourceOrgName -headers $sourceHeaders

        Write-Log -Message "Found $($policies.Count) policies in source.. "

        foreach ($policy in $policies) {
            Write-Log -Message "Attempting to create [$($policy.id)] in target.. "
            try {

                foreach ($entry in $policy.settings.scope) {
                    if ($null -ne $entry.repositoryId) {

                        $sourceRepo = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $TargetHeaders -repoId $entry.repositoryId

                        if ($null -eq $sourceRepo) {
                            Write-Error "Could not find $($entry.repositoryId) in source while attempting to migrate policy." -ErrorAction SilentlyContinue
                        }
                        $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                        if ($null -eq $sourceRepo) {
                            Write-Error "Could not find $($entry.repositoryId) in target while attempting to migrate policy." -ErrorAction SilentlyContinue
                        }
                        $entry.repositoryId = $targetRepo.id
                    }
                }

                New-Policy -projectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders -policy @{
                    "isEnabled"     = $policy.isEnabled
                    "isBlocking"    = $policy.isBlocking
                    "isDeleted"     = $policy.isDeleted
                    "settings"      = $policy.settings
                    "type"          = @{ id = $policy.type.id }
                }
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
            }
        }
    }
}

