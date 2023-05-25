
Param (
        # -------------- What parts of the migration should NOT be executed --------------- \
        # IntelliTect AzureDevOps-Tools Items
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
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigratDeliveryPlans = $TRUE,
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
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWorkItems = $TRUE
)

Import-Module Migrate-ADO -Force

# IntelliTect AzureDevOps-Tools Items
Write-Log -Message "SkipMigrateGroups $($SkipMigrateGroups)"
Write-Log -Message "SkipMigrateBuildQueues $($SkipMigrateBuildQueues)"
Write-Log -Message "SkipMigrateRepos $($SkipMigrateRepos)"
Write-Log -Message "SkipMigrateWikis $($SkipMigrateWikis)"
Write-Log -Message "SkipMigrateServiceHooks $($SkipMigrateServiceHooks)"
Write-Log -Message "SkipMigratePolicies $($SkipMigratePolicies)"
Write-Log -Message "SkipMigrateDashboards $($SkipMigrateDashboards)"
Write-Log -Message "SkipMigrateServiceConnections $($SkipMigrateServiceConnections)"
Write-Log -Message "SkipMigrateArtifacts $($SkipMigrateArtifacts)"
Write-Log -Message "SkipMigratDeliveryPlans $($SkipMigratDeliveryPlans)"


# Azure DevOps Migration Tool Items
Write-Log -Message "SkipMigrateTfsAreaAndIterations $($SkipMigrateTfsAreaAndIterations)"
Write-Log -Message "SkipMigrateTeams $($SkipMigrateTeams)"
Write-Log -Message "SkipMigrateTestVariables $($SkipMigrateTestVariables)"
Write-Log -Message "SkipMigrateTestConfigurations $($SkipMigrateTestConfigurations)"
Write-Log -Message "SkipMigrateTestPlansAndSuites $($SkipMigrateTestPlansAndSuites)"
Write-Log -Message "SkipMigrateWorkItemQuerys $($SkipMigrateWorkItemQuerys)"
Write-Log -Message "SkipMigrateBuildPipelines $($SkipMigrateBuildPipelines)"
Write-Log -Message "SkipMigrateTaskGroups $($SkipMigrateTaskGroups)"
Write-Log -Message "SkipMigrateReleasePipelines $($SkipMigrateReleasePipelines)"
Write-Log -Message "SkipMigrateVariableGroups $($SkipMigrateVariableGroups)"
Write-Log -Message "SkipMigrateWorkItems $($SkipMigrateWorkItems)"
Write-Log -Message ' '


# -------------------------------------------------------------------------------------
# ---------------- Set up files for logging & get configuration values ---------------- 
#region -------------------------------------------------------------------------------
$runDate = (get-date).ToString('yyyy-MM-dd HHmmss')

$configFile = 'configuration.json'
$configPath = 'configuration\'
$filePath = Resolve-Path -Path "$configPath$configFile"

if($NULL -eq $filePath) {
    Write-Host "Checking in project root directory for configuration.json file.."
    $configPath = ''
    $filePath = Resolve-Path -Path "$configPath$configFile"
}
if($NULL -eq $filePath) {
    Write-Log -Message 'Unable to locate configuration.json file which is required!' -LogLevel ERROR
    exit
}

Write-Host "Configuration.json file found.."
$configuration = [Object](Get-Content "$configPath$configFile" | Out-String | ConvertFrom-Json)

$SourceProject = $configuration.SourceProject
$TargetProject = $configuration.TargetProject
$SourceProjectName = $configuration.SourceProject.ProjectName
$TargetProjectName = $configuration.TargetProject.ProjectName
$ProjectDirectory = $configuration.ProjectDirectory
$ScriptDirectoryName = $configuration.ScriptDirectoryName
$WorkItemMigratorDirectory = $configuration.WorkItemMigratorDirectory
$DevOpsMigrationToolConfigurationFile = $configuration.DevOpsMigrationToolConfigurationFile


Write-Host "CONFIGURATION:"
$SourceProject
$TargetProject
$ProjectDirectory
$WorkItemMigratorDirectory

# Organization Level Project Folder Path
# $projectPath = Get-ProjectFolderPath `
#     -RunDate $runDate `
#     -Root $ProjectDirectory

# $env:MIGRATION_LOGS_PATH = $projectPath

# Get project folder & set logging path w/ env variable
$projectPath = Get-ProjectFolderPath `
    -RunDate $runDate `
    -SourceProject $SourceProjectName `
    -TargetProject $TargetProjectName `
    -Root $ProjectDirectory

$env:MIGRATION_LOGS_PATH = $projectPath


# ==========================================
# = Configure Azure DevOps Migration Tool  =
#   Martin's Tool
#region ====================================

$martinConfigPath = "$ProjectDirectory\$($configPath)$DevOpsMigrationToolConfigurationFile"
$martinConfiguration = [Object](Get-Content $martinConfigPath | Out-String | ConvertFrom-Json -Depth 32)
$martinConfigFileChanged = $FALSE

# ------------------
# ----- Source -----
# ------------------
# Organization
if($martinConfiguration.Source.Collection -ne $SourceProject.Organization) {
    $martinConfiguration.Source.Collection = $SourceProject.Organization
    $martinConfigFileChanged = $TRUE
}
# project
if($martinConfiguration.Source.Project -ne $SourceProject.ProjectName) {
    $martinConfiguration.Source.Project = $SourceProject.ProjectName
    $martinConfigFileChanged = $TRUE
}
# personal access token
if($martinConfiguration.Source.PersonalAccessToken -ne $SourceProject.PersonalAccessToken) {
    $martinConfiguration.Source.PersonalAccessToken = $SourceProject.PersonalAccessToken
    $martinConfigFileChanged = $TRUE
}

# ------------------
# ----- Target -----
# ------------------
# Organization
if($martinConfiguration.Target.Collection -ne $TargetProject.Organization) {
    $martinConfiguration.Target.Collection = $TargetProject.Organization
    $martinConfigFileChanged = $TRUE
}
# project
if($martinConfiguration.Target.Project -ne $TargetProject.ProjectName) {
    $martinConfiguration.Target.Project = $TargetProject.ProjectName
    $martinConfigFileChanged = $TRUE
}
# personal access token
if($martinConfiguration.Target.PersonalAccessToken -ne $TargetProject.PersonalAccessToken) {
    $martinConfiguration.Target.PersonalAccessToken = $TargetProject.PersonalAccessToken
    $martinConfigFileChanged = $TRUE
}

# ---------------------------------------
# -- End Point Source/Target settings  --
# ---------------------------------------
$endpointConfigs = @("AzureDevOpsEndpoints", "TfsTeamSettingsEndpoints", "TfsWorkItemEndpoints", "TfsEndpoints")

foreach($endpointConfig in $martinConfiguration.Endpoints.PSObject.Properties) {
    if($endpointConfigs.Contains($endpointConfig.Name)) {
        # Source Organization
        if($endpointConfig.Value[0].Organisation -ne $SourceProject.Organization) {
            $endpointConfig.Value[0].Organisation = $SourceProject.Organization
            $martinConfigFileChanged = $TRUE
        }
        # Source project
        if($endpointConfig.Value[0].Project -ne $SourceProject.ProjectName) {
            $endpointConfig.Value[0].Project = $SourceProject.ProjectName
            $martinConfigFileChanged = $TRUE
        }
        # Source personal access token
        if($endpointConfig.Value[0].AccessToken -ne $SourceProject.PersonalAccessToken) {
            $endpointConfig.Value[0].AccessToken = $SourceProject.PersonalAccessToken
            $martinConfigFileChanged = $TRUE
        }
        if($endpointConfig.Name -eq "TfsWorkItemEndpoints") {
             # Source personal access token
            if($endpointConfig.Value[0].PersonalAccessToken -ne $SourceProject.PersonalAccessToken) {
                $endpointConfig.Value[0].PersonalAccessToken = $SourceProject.PersonalAccessToken
                $martinConfigFileChanged = $TRUE
            }
        }

        # Target Organization
        if($endpointConfig.Value[1].Organisation -ne $TargetProject.Organization) {
            $endpointConfig.Value[1].Organisation = $TargetProject.Organization
            $martinConfigFileChanged = $TRUE
        }
        # Target project
        if($endpointConfig.Value[1].Project -ne $TargetProject.ProjectName) {
            $endpointConfig.Value[1].Project = $TargetProject.ProjectName
            $martinConfigFileChanged = $TRUE
        }
        # Target personal access token
        if($endpointConfig.Value[1].AccessToken -ne $TargetProject.PersonalAccessToken) {
            $endpointConfig.Value[1].AccessToken = $TargetProject.PersonalAccessToken
            $martinConfigFileChanged = $TRUE
        }
        if($endpointConfig.Name -eq "TfsWorkItemEndpoints") {
            # Source personal access token
           if($endpointConfig.Value[1].PersonalAccessToken -ne $TargetProject.PersonalAccessToken) {
               $endpointConfig.Value[1].PersonalAccessToken = $TargetProject.PersonalAccessToken
               $martinConfigFileChanged = $TRUE
           }
       }
    }
}

# --------------------------------------------------
# ----- Azure DevOps Migration Tool Processors -----
# -     enable which processors we execute         -
# --------------------------------------------------
foreach($processor in $martinConfiguration.Processors)
{
    if($processor.'$type' -eq "TfsAreaAndIterationProcessorOptions") {
        if(($processor.Enabled -ne !$SkipMigrateTfsAreaAndIterations)){
            $processor.Enabled = !$SkipMigrateTfsAreaAndIterations
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "TfsTeamSettingsProcessorOptions") {
        if(($processor.Enabled -ne !$SkipMigrateTeams)){
            $processor.Enabled = !$SkipMigrateTeams
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "TestVariablesMigrationConfig") {
        if(($processor.Enabled -ne !$SkipMigrateTestVariables)){
            $processor.Enabled = !$SkipMigrateTestVariables
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "TestConfigurationsMigrationConfig") {
        if(($processor.Enabled -ne !$SkipMigrateTestConfigurations)){
            $processor.Enabled = !$SkipMigrateTestConfigurations
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "TestPlansAndSuitesMigrationConfig") {
        if(($processor.Enabled -ne !$SkipMigrateTestPlansAndSuites)){
            $processor.Enabled = !$SkipMigrateTestPlansAndSuites
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "TfsSharedQueryProcessorOptions") {
        if(($processor.Enabled -ne !$SkipMigrateWorkItemQuerys)){
            $processor.Enabled = !$SkipMigrateWorkItemQuerys
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "AzureDevOpsPipelineProcessorOptions") {
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

            $martinConfigFileChanged = $TRUE
        }
    } elseif(($processor.'$type' -eq "WorkItemMigrationConfig") -or ($processor.'$type' -eq "WorkItemTrackingProcessorOptions")) {
        if(($processor.Enabled -ne !$SkipMigrateWorkItems)){
            $processor.Enabled = !$SkipMigrateWorkItems
            $martinConfigFileChanged = $TRUE
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


if($martinConfigFileChanged) {
    $martinConfiguration | ConvertTo-Json -Depth 32 | Set-Content $martinConfigPath
}
#endregion


# ========================================
# ========== Important Notes =============
# ========================================
# - When migrating service connections make sure you have proper permissions on 
#   zure Active Directory and you can grant Contributor role to the subscription 
#   that was chosen.

# Either separate source and target tokens or same token for source and target
$sourcePat = $env:AZURE_DEVOPS_MIGRATION_SOURCE_PAT
$targetPat = $env:AZURE_DEVOPS_MIGRATION_TARGET_PAT
$pat = $env:AZURE_DEVOPS_MIGRATION_PAT
If ($NULL -eq $sourcePat) {$sourcePat = $pat }
If ($NULL -eq $targetPat) {$targetPat = $pat }

# ========================================
# ========== Migrate Project =============
#region ==================================
Start-ADOProjectMigration `
    -SourceOrgName $configuration.SourceProject.OrgName `
    -SourceProjectName $SourceProjectName `
    -SourcePAT $sourcePat  `
    -SourceProcessId $configuration.SourceProject.ProcessTypeId `
    -TargetOrgName $configuration.TargetProject.OrgName `
    -TargetProjectName $TargetProjectName `
    -TargetPAT $targetPat `
    -TargetProcessId $configuration.TargetProject.ProcessTypeId `
    -ProjectPath $projectPath `
    -ProjectDirectory "$ProjectDirectory\\$ScriptDirectoryName" `
    -configurationDirectory "$ProjectDirectory\\$configPath" `
    -WorkItemMigratorDirectory $WorkItemMigratorDirectory `
    -DevOpsMigrationToolConfigurationFile $DevOpsMigrationToolConfigurationFile `
    -SkipMigrateGroups $SkipMigrateGroups `
    -SkipMigrateBuildQueues $SkipMigrateBuildQueues `
    -SkipMigrateRepos $SkipMigrateRepos `
    -SkipMigrateWikis $SkipMigrateWikis `
    -SkipMigrateServiceHooks $SkipMigrateServiceHooks `
    -SkipMigratePolicies $SkipMigratePolicies `
    -SkipMigrateDashboards $SkipMigrateDashboards `
    -SkipMigrateServiceConnections $SkipMigrateServiceConnections `
    -SkipMigrateArtifacts $SkipMigrateArtifacts `
    -SkipMigratDeliveryPlans $SkipMigratDeliveryPlans `
    -SkipAzureDevOpsMigrationTool $SkipAzureDevOpsMigrationTool
#endregion
