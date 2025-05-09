
Param (
        # -------------- What parts of the migration should NOT be executed --------------- \
        # IntelliTect AzureDevOps-Tools Items
        # Pre-step 
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateOrganizationUsers = $TRUE,

        # Step 1
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildQueues = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateRepos = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWikis = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceConnections = $TRUE,
        # Step 4
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateGroups = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceHooks = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigratePolicies = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDashboards = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDeliveryPlans = $TRUE,
        # Step 5
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateArtifacts = $TRUE,

        # Azure DevOps Migration Tool Items (Martin's Tool)
        # Step 2
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTfsAreaAndIterations = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTeams = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestVariables = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestConfigurations = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestPlansAndSuites = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWorkItemQuerys = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateVariableGroups = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildPipelines = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateReleasePipelines = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTaskGroups = $TRUE,
        
        # Step 3
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWorkItems = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipAddReflectedWorkItemIdField = $TRUE,
        [parameter(Mandatory=$FALSE)] [String]$WorkItemQueryBit = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @TeamProject AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') ORDER BY [System.ChangedDate] DESC"
)


# Import-Module Migrate-ADO -Force

Import-Module .\modules\Migrate-ADO-AreaPaths.psm1
Import-Module .\modules\Migrate-ADO-IterationPaths.psm1
Import-Module .\modules\Migrate-ADO-Users.psm1
Import-Module .\modules\Migrate-ADO-Teams.psm1
Import-Module .\modules\Migrate-ADO-Groups.psm1
Import-Module .\modules\Migrate-ADO-BuildQueues.psm1
Import-Module .\modules\Migrate-ADO-BuildEnvironments.psm1
Import-Module .\modules\Migrate-ADO-Repos.psm1
Import-Module .\modules\Migrate-ADO-Wikis.psm1
Import-Module .\modules\Migrate-ADO-Common.psm1
Import-Module .\modules\Migrate-ADO-Pipelines.psm1
Import-Module .\modules\Migrate-ADO-Project.psm1
Import-Module .\modules\Migrate-ADO-ServiceHooks.psm1
Import-Module .\modules\Migrate-ADO-ServiceConnections.psm1
Import-Module .\modules\Migrate-ADO-VariableGroups.psm1
Import-Module .\modules\Migrate-ADO-Policies.psm1
Import-Module .\modules\Migrate-ADO-Dashboards.psm1
Import-Module .\modules\Migrate-ADO-BuildDefinitions.psm1
Import-Module .\modules\Migrate-ADO-ReleaseDefinitions.psm1
Import-Module .\modules\Migrate-ADO-Artifacts.psm1
Import-Module .\modules\Migrate-ADO-DeliveryPlans.psm1
Import-Module .\modules\ADO-AddCustomField.psm1
Import-Module .\modules\Migrate-Packages.psm1


Write-Log -Message "SkipMigrateBuildQueues $($SkipMigrateBuildQueues)"
Write-Log -Message "SkipMigrateRepos $($SkipMigrateRepos)"
Write-Log -Message "SkipMigrateWikis $($SkipMigrateWikis)"
Write-Log -Message "SkipMigrateServiceConnections $($SkipMigrateServiceConnections)"
Write-Log -Message "SkipMigrateGroups $($SkipMigrateGroups)"
Write-Log -Message "SkipMigrateServiceHooks $($SkipMigrateServiceHooks)"
Write-Log -Message "SkipMigratePolicies $($SkipMigratePolicies)"
Write-Log -Message "SkipMigrateDashboards $($SkipMigrateDashboards)"
Write-Log -Message "SkipMigrateDeliveryPlans $($SkipMigrateDeliveryPlans)"
Write-Log -Message "SkipMigrateArtifacts $($SkipMigrateArtifacts)"


# Azure DevOps Migration Tool Items
Write-Log -Message "SkipMigrateTfsAreaAndIterations $($SkipMigrateTfsAreaAndIterations)"
Write-Log -Message "SkipMigrateTeams $($SkipMigrateTeams)"
Write-Log -Message "SkipMigrateTestVariables $($SkipMigrateTestVariables)"
Write-Log -Message "SkipMigrateTestConfigurations $($SkipMigrateTestConfigurations)"
Write-Log -Message "SkipMigrateTestPlansAndSuites $($SkipMigrateTestPlansAndSuites)"
Write-Log -Message "SkipMigrateWorkItemQuerys $($SkipMigrateWorkItemQuerys)"
Write-Log -Message "SkipMigrateVariableGroups $($SkipMigrateVariableGroups)"
Write-Log -Message "SkipMigrateBuildPipelines $($SkipMigrateBuildPipelines)"
Write-Log -Message "SkipMigrateReleasePipelines $($SkipMigrateReleasePipelines)"
Write-Log -Message "SkipMigrateTaskGroups $($SkipMigrateTaskGroups)"
Write-Log -Message "SkipMigrateWorkItems $($SkipMigrateWorkItems)"
Write-Log -Message " "
Write-Log -Message "WorkItemQueryBit: $($WorkItemQueryBit)"
Write-Log -Message " "



# -------------------------------------------------------------------------------------
# ---------------- Set up files for logging & get configuration values ---------------- 
#region -------------------------------------------------------------------------------
$runDate = (get-date).ToString('yyyy-MM-dd HHmmss')

$configFile = 'configuration.json'
$configPath = 'configuration\'
$filePath = Resolve-Path -Path "$configPath$configFile"

if($NULL -eq $filePath) {
    Write-Log -Message 'Unable to locate configuration.json file which is required!' -LogLevel ERROR
    exit
}

Write-Host "Configuration.json file found.."
$configuration = [Object](Get-Content "$configPath$configFile" | Out-String | ConvertFrom-Json -Depth 100)

$SourceProject = $configuration.SourceProject
$TargetProject = $configuration.TargetProject
$SourceProjectName = $configuration.SourceProject.ProjectName
$TargetProjectName = $configuration.TargetProject.ProjectName
$ProjectDirectory = Get-Location 
$WorkItemMigratorDirectory = $configuration.WorkItemMigratorDirectory
$RepositoryCloneTempDirectory = $configuration.RepositoryCloneTempDirectory
$DevOpsMigrationToolConfigurationFile = $configuration.DevOpsMigrationToolConfigurationFile
$ArtifactFeedPackageVersionLimit = $configuration.ArtifactFeedPackageVersionLimit

Write-Host "CONFIGURATION:"
Write-Host $configuration

# Get project folder & set logging path w/ env variable
$projectPath = Get-ProjectFolderPath `
    -RunDate $runDate `
    -SourceProject $SourceProjectName `
    -TargetProject $TargetProjectName `
    -Root $ProjectDirectory

$env:MIGRATION_LOGS_PATH = $projectPath

# Either separate source and target tokens or same token for source and target
$sourcePat = $env:AZURE_DEVOPS_MIGRATION_SOURCE_PAT
$targetPat = $env:AZURE_DEVOPS_MIGRATION_TARGET_PAT
$pat = $env:AZURE_DEVOPS_MIGRATION_PAT
If ($NULL -eq $sourcePat) {$sourcePat = $pat }
If ($NULL -eq $targetPat) {$targetPat = $pat }


# ==========================================
# = Configure Azure DevOps Migration Tool  =
#   Martin's Tool
#region ====================================

Write-Host "Configure Azure DevOps Migration Tool (Martin's Tool).."

$martinConfigPath = "$($ProjectDirectory)\$($configPath)$DevOpsMigrationToolConfigurationFile"
$martinConfiguration = [Object](Get-Content $martinConfigPath | Out-String | ConvertFrom-Json -Depth 100)
$martinPreviousConfiguration = [Object](Get-Content $martinConfigPath | Out-String | ConvertFrom-Json -Depth 100)


# ---------------------------------------
# -- End Point Source/Target settings  --
# ---------------------------------------
$targetOrg = $configuration.TargetProject.OrgName
Write-Log "targetOrg: $targetOrg"
$url = "https://dev.azure.com/$($targetOrg)/_apis/wit/fields/ReflectedWorkItemId?api-version=7.1-preview.2"
$targetHeaders = New-HTTPHeaders -PersonalAccessToken $targetPat
$DesiredProcessFieldResponse = Invoke-RestMethod -Uri $url -Headers $targetHeaders

$AlternateNameFieldForReflectedWorkItemId = ""
if($null -ne $response -AND $DesiredProcessFieldResponse.referenceName -ne "Custom.ReflectedWorkItemId") {
    $AlternateNameFieldForReflectedWorkItemId = $DesiredProcessFieldResponse.referenceName
}

foreach($endpoint in $martinConfiguration.MigrationTools.Endpoints.PSObject.Properties) {
    
    Write-Host "Name: $($endpoint.Name)"
    
    if($endpoint.Name -like "*Source"){
        $endpoint.Value.Collection = $SourceProject.Organization
        $endpoint.Value.Project = $SourceProject.ProjectName
        $endpoint.Value.Authentication.AccessToken = $sourcePat
        Write-Host "Pat set to $sourcePat"
    } elseif($endpoint.Name -like "*Target"){
        $endpoint.Value.Collection = $TargetProject.Organization
        $endpoint.Value.Project = $TargetProject.ProjectName
        $endpoint.Value.Authentication.AccessToken = $targetPat
        # This replacement only occurs when there is an existing process field named 'ReflectedWorkItemId' which does not have a reference name of Custom.RefelctedWorkItemId
        if(-not [string]::IsNullOrEmpty($AlternateNameFieldForReflectedWorkItemId)){
            $endpoint.Value.ReflectedWorkItemIdField = $AlternateNameFieldForReflectedWorkItemId
        }
    }  
       
}

# --------------------------------------------------
# ----- Azure DevOps Migration Tool Processors -----
# -     enable which processors we execute         -
# --------------------------------------------------
foreach($processor in $martinConfiguration.MigrationTools.Processors)
{
    if($processor.ProcessorType -eq "TfsTeamSettingsProcessor") {
        if(($processor.Enabled -ne !$SkipMigrateTeams)){
            $processor.Enabled = !$SkipMigrateTeams            
        }
    } elseif($processor.ProcessorType -eq "TfsTestVariablesMigrationProcessor") {
        if(($processor.Enabled -ne !$SkipMigrateTestVariables)){
            $processor.Enabled = !$SkipMigrateTestVariables            
        }
    } elseif($processor.ProcessorType -eq "TfsTestConfigurationsMigrationProcessor") {
        if(($processor.Enabled -ne !$SkipMigrateTestConfigurations)){
            $processor.Enabled = !$SkipMigrateTestConfigurations            
        }
    } elseif($processor.ProcessorType -eq "TfsTestPlansAndSuitesMigrationProcessor") {
        if(($processor.Enabled -ne !$SkipMigrateTestPlansAndSuites)){
            $processor.Enabled = !$SkipMigrateTestPlansAndSuites            
        }
    } elseif($processor.ProcessorType -eq "TfsSharedQueryProcessor") {
        if(($processor.Enabled -ne !$SkipMigrateWorkItemQuerys)){
            $processor.Enabled = !$SkipMigrateWorkItemQuerys            
        }
    } elseif($processor.ProcessorType -eq "AzureDevOpsPipelineProcessor") {
        # MigrateBuildPipelines
        $migratingPipeline = $FALSE
        if(($processor.MigrateBuildPipelines -ne !$SkipMigrateBuildPipelines)){
            $processor.MigrateBuildPipelines = !$SkipMigrateBuildPipelines
        }
        if($processor.MigrateBuildPipelines -eq $TRUE) {
            # You need to migrate variable groups before pipelines
            $processor.MigrateVariableGroups = !$SkipMigrateBuildPipelines
            $migratingPipeline = $TRUE
            $SkipMigrateBuildPipelines = $FALSE
        }

        # MigrateReleasePipelines
        if(($processor.MigrateReleasePipelines -ne !$SkipMigrateReleasePipelines)){
            $processor.MigrateReleasePipelines = !$SkipMigrateReleasePipelines
        }
        if($processor.MigrateReleasePipelines -eq $TRUE) {
            # You need to migrate variable groups before pipelines
            $processor.MigrateVariableGroups = !$SkipMigrateReleasePipelines
            $migratingPipeline = $TRUE
            $SkipMigrateBuildPipelines = $FALSE
        }

        # MigrateTaskGroups
        if(($processor.MigrateTaskGroups -ne !$SkipMigrateTaskGroups)){
            $processor.MigrateTaskGroups = !$SkipMigrateTaskGroups
        }

        # MigrateVariableGroups
        if(($processor.MigrateVariableGroups -ne !$SkipMigrateVariableGroups) -and (!$migratingPipeline)){
            $processor.MigrateVariableGroups = !$SkipMigrateVariableGroups
        }

        $SkipAzureDevOpsPipelineProcessorOptions = (  `
            $SkipMigrateBuildPipelines -and  `
            $SkipMigrateReleasePipelines -and  `
            $SkipMigrateVariableGroups -and  `
            $SkipMigrateTaskGroups
        )

        if(($processor.Enabled -ne !$SkipAzureDevOpsPipelineProcessorOptions) -or (!$SkipAzureDevOpsPipelineProcessorOptions)){
            $processor.Enabled = !$SkipAzureDevOpsPipelineProcessorOptions

            # RepositoryNameMaps
            if($processor.Enabled -eq $TRUE) {
                $processor.RepositoryNameMaps = @{
                    "$($SourceProject.ProjectName)"= "$($TargetProject.ProjectName)"
                }
            } else {
                $processor.RepositoryNameMaps = $NULL
            }

            
        }
    } elseif(($processor.ProcessorType -eq "TfsWorkItemMigrationProcessor") -or ($processor.ProcessorType -eq "WorkItemTrackingProcessorOptions")) {
        if(($processor.Enabled -ne !$SkipMigrateWorkItems) -or ($processor.WIQLQuery -ne $WorkItemQueryBit)){
            $processor.Enabled = !$SkipMigrateWorkItems
            $processor.WIQLQuery = $WorkItemQueryBit
            
        }
    }
}

$SkipAzureDevOpsMigrationTool = (  `
    $SkipMigrateTfsAreaAndIterations -and  `
    $SkipMigrateTeams -and  `
    $SkipMigrateTestVariables -and  `
    $SkipMigrateTestConfigurations -and  `
    $SkipMigrateTestPlansAndSuites -and  `
    $SkipMigrateWorkItemQuerys -and  `
    $SkipMigrateBuildPipelines -and  `
    $SkipMigrateReleasePipelines -and  `
    $SkipMigrateTaskGroups -and  `
    $SkipMigrateVariableGroups -and  `
    $SkipMigrateWorkItems
)


$martinConfiguration | ConvertTo-Json -Depth 100 | Set-Content $martinConfigPath
$configString = $martinConfiguration | ConvertTo-Json -Depth 100
Write-Host "Configuration after substitution:"
Write-Host $configString
#endregion


# ========================================
# ========== Important Notes =============
# ========================================
# - When migrating service connections make sure you have proper permissions on 
#   zure Active Directory and you can grant Contributor role to the subscription 
#   that was chosen.


# ========================================
# ========== Migrate Project =============
#region ==================================
Start-ADOProjectMigration `
    -SourceOrgName $configuration.SourceProject.OrgName `
    -SourceProjectName $SourceProjectName `
    -SourcePAT $sourcePat  `
    -TargetOrgName $configuration.TargetProject.OrgName `
    -TargetProjectName $TargetProjectName `
    -TargetPAT $targetPat `
    -ProjectPath $projectPath `
    -RepositoryCloneTempDirectory $RepositoryCloneTempDirectory `
    -MartinsToolConfigurationFile $martinConfigPath `
    -WorkItemMigratorDirectory $WorkItemMigratorDirectory `
    -DevOpsMigrationToolConfigurationFile $DevOpsMigrationToolConfigurationFile `
    -ArtifactFeedPackageVersionLimit $ArtifactFeedPackageVersionLimit `
    -SkipMigrateGroups $SkipMigrateGroups `
    -SkipMigrateBuildQueues $SkipMigrateBuildQueues `
    -SkipMigrateRepos $SkipMigrateRepos `
    -SkipMigrateWikis $SkipMigrateWikis `
    -SkipMigrateServiceHooks $SkipMigrateServiceHooks `
    -SkipMigratePolicies $SkipMigratePolicies `
    -SkipMigrateDashboards $SkipMigrateDashboards `
    -SkipMigrateServiceConnections $SkipMigrateServiceConnections `
    -SkipMigrateArtifacts $SkipMigrateArtifacts `
    -SkipMigrateDeliveryPlans $SkipMigrateDeliveryPlans `
    -SkipAzureDevOpsMigrationTool $SkipAzureDevOpsMigrationTool `
    -SkipMigrateOrganizationUsers $SkipMigrateOrganizationUsers `
    -SkipAddReflectedWorkItemIdField $SkipAddReflectedWorkItemIdField
#endregion


# Clean up old martin's tool Configuration
Write-Host "Clean up Configuration file for Azure DevOps Migration Tool (Martin's Tool).."

$martinPreviousConfiguration | ConvertTo-Json -Depth 100 | Set-Content $martinConfigPath

