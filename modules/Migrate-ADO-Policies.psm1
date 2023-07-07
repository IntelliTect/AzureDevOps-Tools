
function Start-ADOPoliciesMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT
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

        Write-Log -Message "Get Source Policies.."
        $sourcePolicies = Get-Policies -ProjectName $SourceProjectName -orgName $SourceOrgName -headers $sourceHeaders
        Write-Log -Message "Get Target Policies.."
        $targetPolicies = Get-Policies -ProjectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders
       
        Write-Log -Message "Get Target Pipelines to do source lookups.."
        $targetPipelines = Get-Pipelines -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName

        Write-Log -Message "Get Target Repositories to do source lookups.."
        $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders

        # $sourceUsers = Get-ADOUsersByAPI -OrgName $SourceOrgName -Headers $SourceHeaders
        # Write-Log -Message "Get Source Users to do source lookups.."
        Write-Log -Message "Get Target Users to do source lookups.."
        $targetUsers = Get-ADOUsersByAPI -OrgName $TargetOrgName -Headers $TargetHeaders

        Write-Log -Message "Get Source Groups to do source lookups.."
        $sourceGroups = Get-ADOGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName -PersonalAccessToken $SourcePAT
        Write-Log -Message "Get Target Groups to do source lookups.."
        $targetGroups = Get-ADOGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName -PersonalAccessToken $TargetPAT


        Write-Log -Message "Found $($sourcePolicies.Count) policies in source.. "
        
        foreach ($policy in $sourcePolicies) {

            if($policy.id -ne 360) {
                continue
            }

            Write-Log -Message "Attempting to find $($policy.type.displayName) [$($policy.id)] in target.. "
            try {
                foreach ($entry in $policy.settings.scope) {
                    if ($null -ne $entry.repositoryId) {

                        $sourceRepo = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $TargetHeaders -repoId $entry.repositoryId
                        if ($null -eq $sourceRepo) {
                            Write-Log -Message "Could not find $($entry.repositoryId) in source while attempting to migrate policy." -LogLevel ERROR
                        }

                        $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                        if ($null -eq $targetRepo) {
                            Write-Log -Message "Could not find $($entry.name) [$($entry.repositoryId)] in target while attempting to migrate policy." -LogLevel ERROR
                        }

                        $entry.repositoryId = $targetRepo.id
                    }
                }

                if($NULL -ne $policy.settings.buildDefinitionId) {
                    $sourcePipeline = Get-Pipeline -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName -DefinitionId $policy.settings.buildDefinitionId
                    $targetPipeline = ($targetPipelines | Where-Object {$_.Name -ceq $sourcePipeline.Name})
                    if ($null -ne $targetPipeline) {
                        $policy.settings.buildDefinitionId = $targetPipeline.id
                    } else {
                        Write-Log -Message "Could not find Target pipeline in settings.buildDefinitionId $($policy.settings.buildDefinitionId) in Policy ID [$($policy.id)] while attempting to migrate policy." -LogLevel ERROR
                        continue
                    }
                }

                if($NULL -ne $policy.settings.requiredReviewerIds) {
                    $failedToFindReviewerId = $FALSE
                    $newRequiredReviewerIds = @()
                    foreach($Id in $policy.settings.requiredReviewerIds){
                        # Search Users for the requiredReviewerId 
                        $targetUser = ($targetUsers | Where-Object { $_.Id -ceq $Id })
                        if ($null -eq $targetUser) {
                            # Search Groups for the requiredReviewerId 
                            $existingGroup = $sourceGroups | Where-Object { $_.Id -ceq $Id }
                            $migratedGroup = $targetGroups | Where-Object { $_.Name -ceq $existingGroup.Name }
                            if ($null -eq $migratedGroup) {
                                $failedToFindReviewerId = $TRUE
                            } else {
                                $newRequiredReviewerIds += $migratedGroup.Id
                            }
                        }
                    }

                    if($failedToFindReviewerId -eq $TRUE) {
                        Write-Log -Message "Could not find one or more of the Required Reviewer Ids ($($policy.settings.requiredReviewerIds)) in Policy ID [$($policy.id)] while attempting to migrate policy." -LogLevel ERROR
                        continue
                    } else {
                        $policy.settings.requiredReviewerIds = $newRequiredReviewerIds
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
            } catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
            }
        }
       
    }
}


function Get-Policies([string]$projectName, [string]$orgName, $headers) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/policy/configurations?api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}

function New-Policy([string]$projectName, [string]$orgName, $headers, $policy) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/policy/configurations?api-version=7.0"
    
    $body = $policy | ConvertTo-Json -Depth 10

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}



