
param (
    [Parameter (Mandatory = $TRUE)]
    [String]$SourceOrgName, 

    [Parameter (Mandatory = $TRUE)]
    [String]$SourceProjectName, 
    
    [Parameter (Mandatory = $TRUE)]
    [String]$SourcePAT,

    [Parameter (Mandatory = $TRUE)]
    [String]$TargetOrgName, 

    [Parameter (Mandatory = $TRUE)]
    [String]$TargetProjectName, 
    
    [Parameter (Mandatory = $TRUE)]
    [String]$TargetPAT,

    [Parameter (Mandatory = $TRUE)]
    [String]$OutputFile
    
)

    Write-Host " "
    Write-Host '-----------------------------------------'
    Write-Host '-- Validate Migrate Build Environments --'
    Write-Host '-----------------------------------------'
    Write-Host " "

        # Create Headers
    $SourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
    $Targetheaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

    Start-Transcript -Path $OutputFile -Append

    Write-Host "Get Source Project to do source lookups.."
    $sourceProject = Get-ADOProjects -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders
    Write-Host "Get target Project to do source lookups.."
    $targetProject = Get-ADOProjects -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders

    Write-Host "Get Source Environments.."
    $sourceEnvironments = Get-BuildEnvironments -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -ProjectId $sourceProject.Id -Top 1000000
    Write-Host "Get Target Environments.."
    $targetEnvironments = Get-BuildEnvironments -ProjectName $TargetProjectName -OrgName $TargetOrgName -Headers $Targetheaders -ProjectId $targetProject.Id -Top 1000000

    Write-Host " "
    Write-Host " "
    Write-Host "Source Environments Count: $($sourceEnvironments.Count)"
    Write-Host "Target Environments Count: $($targetEnvironments.Count)"
    Write-Host " "

    $environmentsInSourceNotInTarget = $sourceEnvironments | Where-Object { $_.name -notin $targetEnvironments.name }
    Write-Host "Environments in Source not in Target:"
    foreach ($env1 in $environmentsInSourceNotInTarget) {
        Write-Host "$($env1.name)"
    }

    $environmentsInTargetNotInSource = $targetEnvironments | Where-Object { $_.name -notin $sourceEnvironments.name }
    Write-Host "Environments in Target not in Source:"
    foreach ($env2 in $environmentsInTargetNotInSource) {
        Write-Host "$($env2.name)"
    }


    foreach ($sourceEnvironment in $sourceEnvironments) {
        $sourceEnvName = $sourceEnvironment.name
        $sourceEnvId = $sourceEnvironment.id

        Write-Host "----- Environment $($sourceEnvName) - $($sourceEnvId) -----"
        Write-Host " "
        $targetEnvironment = $targetEnvironments | Where-Object { $_.Name -ieq $sourceEnvironment.Name }

        
        Write-Host "--- User permissions --- "
        # $sourceRoleAssignments = Get-BuildEnvironmentRoleAssignments -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -ProjectId $sourceProject.Id -EnvironmentId $newEnvironment.Id
        $url = "https://dev.azure.com/$SourceOrgName/_apis/securityroles/scopes/distributedtask.environmentreferencerole/roleassignments/resources/$($sourceProject.Id)_$($sourceEnvironment.Id)"
        $results1 = Invoke-RestMethod -Method Get -uri $url -Headers $SourceHeaders
        Write-Host "Source Environment $($sourceEnvironment.Name) RoleAssignment Count: $($results1.Value.Count)"

        $url = "https://dev.azure.com/$TargetOrgName/_apis/securityroles/scopes/distributedtask.environmentreferencerole/roleassignments/resources/$($targetProject.Id)_$($targetEnvironment.Id)"
        $results2 = Invoke-RestMethod -Method Get -uri $url -Headers $TargetHeaders
        Write-Host "Target Environment $($sourceEnvironment.Name) RoleAssignment Count: $($results2.Value.Count)"


        Write-Host "--- Pipline permissions --- "
        # $sourcePipelinePermissions = Get-BuildEnvironmentPipelinePermissions -ProjectName $SourceProjectName -OrgName $SourceOrgName -Headers $Sourceheaders -EnvironmentId $newEnvironment.Id
        $url = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/pipelines/pipelinePermissions/environment/$($sourceEnvironment.Id)"
        $results3 = Invoke-RestMethod -Method Get -uri $url -Headers $SourceHeaders
        Write-Host "Source Environment $($sourceEnvironment.Name) RoleAssignment Count: $($results3.Pipelines.Count)"

        $url = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/pipelines/pipelinePermissions/environment/$($targetEnvironment.Id)"
        $results4 = Invoke-RestMethod -Method Get -uri $url -Headers $TargetHeaders
        Write-Host "Target Environment $($targetEnvironment.Name) RoleAssignment Count: $($results4.Pipelines.Count)"
        Write-Host "--------------------------------------------------"

        Write-Host " "

    }

    Write-Host " "
    Stop-Transcript
