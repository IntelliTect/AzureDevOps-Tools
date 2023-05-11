
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

        $sourcePolicies = Get-Policies -ProjectName $SourceProjectName -orgName $SourceOrgName -headers $sourceHeaders
        $targetPolicies = Get-Policies -ProjectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders
       
        $TargetPipelines = Get-Pipelines -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName
        $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders

        $targetUsers = Get-ADOUsersByAPI -OrgName $targetOrgName -Headers $TargetHeaders

        Write-Log -Message "Found $($sourcePolicies.Count) policies in source.. "
        
        foreach ($policy in $sourcePolicies) {
            Write-Log -Message "Attempting to find $($policy.type.displayName) [$($policy.id)] in target.. "
            try {
                foreach ($entry in $policy.settings.scope) {
                    if ($null -ne $entry.repositoryId) {

                        $sourceRepo = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $TargetHeaders -repoId $entry.repositoryId
                        if ($null -eq $sourceRepo) {
                            Write-Error "Could not find $($entry.repositoryId) in source while attempting to migrate policy." -ErrorAction SilentlyContinue
                        }

                        $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                        if ($null -eq $targetRepo) {
                            Write-Error "Could not find $($entry.name) [$($entry.repositoryId)] in target while attempting to migrate policy." -ErrorAction SilentlyContinue
                        }

                        $entry.repositoryId = $targetRepo.id
                    }
                }

                if($NULL -ne $policy.settings.buildDefinitionId) {
                    $sourcePipeline = Get-Pipeline -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName -DefinitionId $policy.settings.buildDefinitionId
                    $targetPipeline = ($TargetPipelines | Where-Object {$_.Name -ceq $sourcePipeline.Name})
                    if ($null -ne $targetPipeline) {
                        $policy.settings.buildDefinitionId = $targetPipeline.id
                    } else {
                        Write-Error "Could not find Target pipeline in settings.buildDefinitionId $($policy.settings.buildDefinitionId) in Policy ID [$($policy.id)] while attempting to migrate policy." -ErrorAction SilentlyContinue
                        continue
                    }
                }

                if($NULL -ne $policy.settings.requiredReviewerIds) {
                    $failedToFindUser = $FALSE
                    foreach($userId in $policy.settings.requiredReviewerIds){
                        $targetUser = ($targetUsers | Where-Object {$_.id -ceq $userId})
                        if ($null -eq $targetUser) {
                            Write-Error "Could not find map Target User in settings.requiredReviewerIds $($policy.settings.requiredReviewerIds) in Policy ID [$($policy.id)] while attempting to migrate policy." -ErrorAction SilentlyContinue
                            $failedToFindUser = $TRUE
                        }
                    }
                    if($failedToFindUser -eq $TRUE) {
                        continue
                    }
                }

                # See if Policy exists in Target with the same Policy Type ID and matching settings.Scopes
                $likePolicies = $targetPolicies | Where-Object {(($_.type.id -eq $policy.type.id) -and ($_.settings.scope.Count -eq $policy.settings.scope.Count))} 
                $matchedItems = New-Object Collections.Generic.List[Int]
                if($NULL -ne $likePolicies) {
                    foreach($likePolicy in $likePolicies) {
                        $policyFound = $TRUE
                        foreach($likePolicyScope in $likePolicy.settings.scope) {
                            $scopeFound = $FALSE
                            foreach($policyScope in $policy.settings.scope) {
                                if(($policyScope.refName -ceq $likePolicyScope.refName) -and ($policyScope.matchKind -eq $likePolicyScope.matchKind) -and ($policyScope.repositoryId -eq $likePolicyScope.repositoryId)) {
                                    $scopeFound = $TRUE
                                    break
                                }
                            }
                            if($scopeFound) {
                                continue
                            } else {
                                $policyFound = $FALSE
                                break
                            }
                        }
                    
                        if($policyFound -eq $TRUE) {
                            $matchedItems.Add($likePolicy.id)
                        }
                    }
                }
                
                if ($matchedItems.Count -gt 0) {
                    Write-Log -Message "Policy $($policy.type.displayName) [$($policy.id)] already exists in target.. "
                    if ($matchedItems.Count -gt 1) {
                        Write-Log -Message "Found more than one Policy in Target that matches Source Policy $($policy.type.displayName) [$($policy.id)]... "
                    }
                    continue
                } 

                Write-Log -Message "Creating NEW $($policy.type.displayName) [Id: $($policy.id)] policy in target !" -LogLevel SUCCESS
                $result = New-Policy -projectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders -policy $policy
                Write-Host $result
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

