
Using Module ".\Migrate-ADO-Common.psm1"

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
        $sourcePolicies = Get-Policies -ProjectName $SourceProjectName -orgName $SourceOrgName -headers $SourceHeaders
        # Write-Log -Message "Get Target Policies.."
        # $targetPolicies = Get-Policies -ProjectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders
       
        # Write-Log -Message "Get Source Pipelines for source to target mapping.."
        $sourcePipelines = Get-Pipelines -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName
        # Write-Log -Message "Get Target Pipelines for source to target mapping.."
        $targetPipelines = Get-Pipelines -Headers $TargetHeaders -OrgName $TargetOrgName -ProjectName $TargetProjectName

        # Write-Log -Message "Get Target Repositories for source to target mapping.."
        $sourceRepos = Get-Repos -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders
        Write-Log -Message "Get Target Repositories for source to target mapping.."
        $targetRepos = Get-Repos -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $TargetHeaders

        # Write-Log -Message "Get Source Users for source to target mapping.."
        # $sourceUsers = Get-ADOUsersByAPI -OrgName $SourceOrgName -Headers $SourceHeaders
        # # Write-Log -Message "Get Target Users for source to target mapping.."
        # $targetUsers = Get-ADOUsersByAPI -OrgName $TargetOrgName -Headers $TargetHeaders

        Write-Log -Message 'Getting ADO Users from Source..'
        $sourceUsers = Get-ADOUsers  -OrgName $SourceOrgName -PersonalAccessToken $SourcePat
        Write-Log -Message 'Getting ADO Users from Target..'
        $targetUsers = Get-ADOUsers -OrgName $TargetOrgName -PersonalAccessToken $TargetPat

        Write-Log -Message "Get Source Groups for source to target mapping.."
        $sourceGroups = Get-ADOGroups -OrgName $SourceOrgName -ProjectName $SourceProjectName -PersonalAccessToken $SourcePAT -GetGroupMembers $FALSE
        Write-Log -Message "Get Target Groups for source to target mapping.."
        $targetGroups = Get-ADOGroups -OrgName $TargetOrgName -ProjectName $TargetProjectName -PersonalAccessToken $TargetPAT -GetGroupMembers $FALSE

        Write-Log -Message "Found $($sourcePolicies.Count) policies in source.. "

        foreach ($policy in $sourcePolicies) {
            Write-Log -Message "Processing Policy `"$($policy.type.displayName)`" [$($policy.Id)].. "
            $strMsg = ""
            $processPolicy = $policy
            try {
                $haveMissingComponents = $FALSE
                foreach ($entry in $processPolicy.settings.scope) {
                    if ($null -ne $entry.repositoryId) {
                        Write-Log -Message "Mapping  repository id $($entry.repositoryId).. "
                        # $sourceRepo = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $TargetHeaders -repoId $entry.repositoryId
                        $sourceRepo = $sourceRepos | Where-Object { $_.Id -eq $entry.repositoryId }
                        if ($null -eq $sourceRepo) {
                            $sourceRepo = Get-Repo -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $TargetHeaders -repoId $entry.repositoryId
                        }

                        if ($null -ne $sourceRepo) {
                            $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
                            if ($null -eq $targetRepo) {
                                $strMsg += ("Could not find the repositoryId $($entry.name) [$($entry.repositoryId)] in target while attempting to migrate policy." + "`n")
                                # Write-Log -Message "Could not find the repositoryId $($entry.name) [$($entry.repositoryId)] in target while attempting to migrate policy." -LogLevel WARNING
                                $haveMissingComponents = $TRUE
                                $entry.repositoryId = $NULL
                            } else {
                                $entry.repositoryId = $targetRepo.id
                            }
                        } else {
                            $strMsg += ("Could not find the repositoryId $($entry.repositoryId) in source while attempting to migrate policy." + "`n")
                            # Write-Log -Message "Could not find the repositoryId $($entry.repositoryId) in source while attempting to migrate policy." -LogLevel WARNING
                            $haveMissingComponents = $TRUE
                        }
                    }
                }

                if($NULL -ne $processPolicy.settings.buildDefinitionId) {
                    Write-Log -Message "Mapping  buildDefinitionId id $($processPolicy.settings.buildDefinitionId).. "
                    # $sourcePipeline = Get-Pipeline -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName -DefinitionId $processPolicy.settings.buildDefinitionId
                    $sourcePipeline = $sourcePipelines | Where-Object { $_.Id -eq $processPolicy.settings.buildDefinitionId }
                    if($NULL -eq $sourcePipeline) {
                        $sourcePipeline = Get-Pipeline -Headers $SourceHeaders -OrgName $SourceOrgName -ProjectName $SourceProjectName -DefinitionId $processPolicy.settings.buildDefinitionId
                    }

                    if($NULL -ne $sourcePipeline) {
                        $targetPipeline = ($targetPipelines | Where-Object {$_.Name -eq $sourcePipeline.Name})
                        if ($null -ne $targetPipeline) {
                            $processPolicy.settings.buildDefinitionId = $targetPipeline.id
                        } else {
                            $strMsg += ("Could not find Target pipeline for settings.buildDefinitionId $($processPolicy.settings.buildDefinitionId) in Policy ID [$($processPolicy.id)] while attempting to migrate policy." + "`n")
                            # Write-Log -Message "Could not find Target pipeline in settings.buildDefinitionId $($processPolicy.settings.buildDefinitionId) in Policy ID [$($processPolicy.id)] while attempting to migrate policy." -LogLevel WARNING
                            $haveMissingComponents = $TRUE
                            #continue
                            # $processPolicy.settings.buildDefinitionId = $NULL
                        }
                    } else {
                        $strMsg += ("Could not find Source pipeline for settings.buildDefinitionId $($processPolicy.settings.buildDefinitionId) in Policy ID [$($processPolicy.id)] while attempting to migrate policy." + "`n")
                        $haveMissingComponents = $TRUE
                    }
                    
                }

                if($NULL -ne $processPolicy.settings.requiredReviewerIds) {
                    Write-Log -Message "Mapping Required Reviewer Ids ($($policy.settings.requiredReviewerIds)) in Policy ID [$($policy.id)] from source to target."
                    $failedToFindReviewerId = $FALSE
                    $newRequiredReviewerIds = @()
                    foreach($Id in $processPolicy.settings.requiredReviewerIds){
                        # Search Users for the requiredReviewerId 
                        # Write-Log -Message "Attempting to locate Required Reviewer Id ($($Id)) in Policy ID [$($policy.id)] while attempting to migrate policy."
                        $existingGroup = $sourceGroups | Where-Object { $_.Id -eq $Id }
                        $migratedGroup = $targetGroups | Where-Object { $_.Name -eq $existingGroup.Name }
                        if ($NULL -ne $migratedGroup) {
                            $newRequiredReviewerIds += $migratedGroup.Id
                        } else {
                            $sourceUser = ($sourceUsers | Where-Object { $_.Id -eq $Id })
                            $targetUser = ($targetUsers | Where-Object { $_.MailAddress -eq $sourceUser.MailAddress })
                            if ($NULL -ne $targetUser) {
                                $newRequiredReviewerIds += $targetUser.Id
                            } else {
                                $strMsg += ("Could not find Required Reviewer Id: ($($Id)) for Policy ID [$($policy.id)] in target Groups or users." + "`n")
                                # Write-Log -Message "Could not find Required Reviewer Id: ($($Id)) for Policy ID [$($policy.id)] in target Groups or users." -LogLevel WARNING
                                $failedToFindReviewerId = $TRUE
                            }
                        }
                    }

                    if($failedToFindReviewerId -eq $TRUE) {
                        $haveMissingComponents = $TRUE
                    } else {
                        $processPolicy.settings.requiredReviewerIds = $newRequiredReviewerIds
                    }
                }

                if($haveMissingComponents) {
                    Write-Log -Message "Unable to create NEW Policy for Source Policy '$($processPolicy.type.displayName)' [Id: $($processPolicy.id)] in target!" -LogLevel ERROR
                    Write-Log -Message $strMsg -LogLevel ERROR
                    # $policyJson = ConvertTo-Json -Depth 100 $processPolicy
                    # Write-Log -Message $policyJson -LogLevel INFO
                    continue
                }

                Write-Log -Message "Attempting to create or locate migrated Policy '$($processPolicy.type.displayName)' [Id: $($processPolicy.id)] in target!"
                try {
                    $result = New-Policy -projectName $targetProjectName -orgName $targetOrgName -headers $targetHeaders -policy $processPolicy
                    Write-Log -Message "Created NEW Policy '$($processPolicy.type.displayName)' [Id: $($processPolicy.id)] in target!"
                    Write-Log -Message "Done!" -LogLevel SUCCESS
                    Write-Host $result
                } catch {
                    $err = ConvertFrom-json -Depth 100 $_
                    if($err.typeKey -eq "PolicyChangeRejectedByPolicyException") {
                        Write-Log -Message "Policy '$($processPolicy.type.displayName)' [Id: $($processPolicy.id)] already exist in target."
                    } else {
                        Write-Log -Message ($_) -LogLevel ERROR
                        Write-Log -Message $_.Exception -LogLevel ERROR
                    }
                }
                
                Write-Host " "
            } catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                    Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
            }
        }
        # TEMP FOR TESTING ONLY
        Stop-Transcript
    }
}


function Get-Policies([string]$projectName, [string]$orgName, $headers) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/policy/configurations"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return , $results.value

}

function Get-UserIdentity ([string]$projectName, [string]$orgName, $headers, $identityId) {

    $url = "https://vssps.dev.azure.com/$orgName/_apis/identities?identityIds=$($identityId)&api-version=7.0"
           
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

    return $results.Value

}

function Get-UserByDescriptor ([string]$projectName, [string]$orgName, $headers, $descriptorId) {

    $url = "https://vssps.dev.azure.com/$orgName/_apis/Graph/Users/$($descriptorId)?api-version=7.0-preview"
           
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

    return $results

}

function New-Policy([string]$projectName, [string]$orgName, $headers, $policy) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/policy/configurations?api-version=7.0"
    
    $body = ConvertTo-Json -Depth 100 $policy 

    $results = Invoke-RestMethod -Method POST -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}

function Edit-Policy([string]$projectName, [string]$orgName, $headers, $policy) {

    $url = "https://dev.azure.com/$orgName/$projectName/_apis/policy/configurations/$($policy.Id)?api-version=7.0"
    
    $body = ConvertTo-Json -Depth 100 $policy

    $results = Invoke-RestMethod -Method PUT -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}

