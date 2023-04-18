
Param (
        # -------------- What parts of the migration should NOT be executed --------------- \
        # IntelliTect AzureDevOps-Tools Items
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateGroups = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildQueues = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateRepos = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWikis = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceHooks = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigratePolicies = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDashboards = $FALSE,
        # [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildDefinitions = $TRUE,
        # [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateReleaseDefinitions = $TRUE,

        # Azure DevOps Migration Tool Items (Martin's Tool)
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTeams = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestVariables = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestConfigurations = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTestPlansAndSuites = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWorkItemQuerys = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildPipelines = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateReleasePipelines = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTaskGroups = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateVariableGroups = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceConnections = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateTfsAreaAndIterations = $FALSE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWorkItems = $TRUE,
        # Custom field for migration
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipAddADOCustomField = $TRUE
)

Import-Module Migrate-ADO -Force


# -------------------------------------------------------------------------------------
# ---------------- Set up files for logging & get configuration values ---------------- 
#region -------------------------------------------------------------------------------
$runDate = (get-date).ToString('yyyy-MM-dd HHmmss')
$configuration = [Object](Get-Content 'configuration.json' | Out-String | ConvertFrom-Json)

$SourceProject = $configuration.SourceProject
$TargetProject = $configuration.TargetProject
$SourceProjectName = $configuration.SourceProject.ProjectName
$TargetProjectName = $configuration.TargetProject.ProjectName
# $SavedAzureQuery = $configuration.SavedAzureQuery
$ProjectDirectory = $configuration.ProjectDirectory
$ScriptDirectoryName = $configuration.ScriptDirectoryName
$WorkItemMigratorDirectory = $configuration.WorkItemMigratorDirectory
$DevOpsMigrationToolConfigurationFile = $configuration.DevOpsMigrationToolConfigurationFile


Write-Host "CONFIGURATION:"
$SourceProject
$TargetProject
# $SavedAzureQuery
$ProjectDirectory
$WorkItemMigratorDirectory


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

$martinConfigPath = "$ProjectDirectory\migration-scripts\$DevOpsMigrationToolConfigurationFile"
$martinConfiguration = [Object](Get-Content $martinConfigPath | Out-String | ConvertFrom-Json)
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
if($martinConfiguration.Source.PersonalAccessTokenVariableName -ne $SourceProject.PersonalAccessTokenVariableName) {
    $martinConfiguration.Source.PersonalAccessTokenVariableName = $SourceProject.PersonalAccessTokenVariableName
    $martinConfigFileChanged = $TRUE
}
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
if($martinConfiguration.Target.PersonalAccessTokenVariableName -ne $TargetProject.PersonalAccessTokenVariableName) {
    $martinConfiguration.Target.PersonalAccessTokenVariableName = $TargetProject.PersonalAccessTokenVariableName
    $martinConfigFileChanged = $TRUE
}
if($martinConfiguration.Target.PersonalAccessToken -ne $TargetProject.PersonalAccessToken) {
    $martinConfiguration.Target.PersonalAccessToken = $TargetProject.PersonalAccessToken
    $martinConfigFileChanged = $TRUE
}

# ---------------------------------
# -- AzureDevOpsEndpoints Blocks --
# ---------------------------------

if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].name -ne "Source") {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].name = "Source"
}
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].name -ne "Target") {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].name = "Target"
}

# ---------------------------------------
# ----- AzureDevOpsEndpoints Source -----
# ---------------------------------------
# Organization
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].Organisation -ne $SourceProject.Organization) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].Organisation = $SourceProject.Organization
    $martinConfigFileChanged = $TRUE
}
# project
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].Project -ne $SourceProject.ProjectName) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].Project = $SourceProject.ProjectName
    $martinConfigFileChanged = $TRUE
}
# personal access token
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].AccessToken -ne $SourceProject.PersonalAccessToken) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[0].AccessToken = $SourceProject.PersonalAccessToken
    $martinConfigFileChanged = $TRUE
}

# ---------------------------------------
# ----- AzureDevOpsEndpoints Target -----
# ---------------------------------------
# Organization
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].Organisation -ne $TargetProject.Organization) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].Organisation = $TargetProject.Organization
    $martinConfigFileChanged = $TRUE
}
# project
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].Project -ne $TargetProject.ProjectName) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].Project = $TargetProject.ProjectName
    $martinConfigFileChanged = $TRUE
}
# personal access token
if($martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].AccessToken -ne $TargetProject.PersonalAccessToken) {
    $martinConfiguration.Endpoints.AzureDevOpsEndpoints[1].AccessToken = $TargetProject.PersonalAccessToken
    $martinConfigFileChanged = $TRUE
}

# --------------------------------------------------
# ----- Azure DevOps Migration Tool Processors -----
# -     enable which processors we execute         -
# --------------------------------------------------
foreach($processor in $martinConfiguration.Processors)
{
    if ($processor.'$type' -eq "TeamMigrationConfig") {
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
    } elseif($processor.'$type' -eq "WorkItemQueryMigrationConfig") {
        if(($processor.Enabled -ne !$SkipMigrateWorkItemQuerys)){
            $processor.Enabled = !$SkipMigrateWorkItemQuerys
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "AzureDevOpsPipelineProcessorOptions") {
        # MigrateBuildPipelines
        if(($processor.MigrateBuildPipelines -ne !$SkipMigrateBuildPipelines)){
            $processor.MigrateBuildPipelines = !$SkipMigrateBuildPipelines
        }

        # MigrateReleasePipelines
        if(($processor.MigrateReleasePipelines -ne !$SkipMigrateReleasePipelines)){
            $processor.MigrateReleasePipelines = !$SkipMigrateReleasePipelines
        }

        # MigrateTaskGroups
        if(($processor.MigrateTaskGroups -ne !$SkipMigrateTaskGroups)){
            $processor.MigrateTaskGroups = !$SkipMigrateTaskGroups
        }

        # MigrateVariableGroups
        if(($processor.MigrateVariableGroups -ne !$SkipMigrateVariableGroups)){
            $processor.MigrateVariableGroups = !$SkipMigrateVariableGroups
        }

        # MigrateServiceConnections
        if(($processor.MigrateServiceConnections -ne !$SkipMigrateServiceConnections)){
            $processor.MigrateServiceConnections = !$SkipMigrateServiceConnections
        }

        $SkipAzureDevOpsPipelineProcessorOptions = (  `
            $SkipMigrateBuildPipelines -and  `
            $SkipMigrateReleasePipelines -and  `
            $SkipMigrateVariableGroups -and  `
            $SkipMigrateTaskGroups -and  `
            $SkipMigrateServiceConnections
        )

        if(($processor.Enabled -ne !$SkipAzureDevOpsPipelineProcessorOptions)){
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
    } elseif($processor.'$type' -eq "TfsAreaAndIterationProcessorOptions") {
        if(($processor.Enabled -ne !$SkipMigrateTfsAreaAndIterations)){
            $processor.Enabled = !$SkipMigrateTfsAreaAndIterations
            $martinConfigFileChanged = $TRUE
        }
    } elseif($processor.'$type' -eq "WorkItemMigrationConfig") {
        if(($processor.Enabled -ne !$SkipMigrateWorkItems)){
            $processor.Enabled = !$SkipMigrateWorkItems
            $martinConfigFileChanged = $TRUE
        }
    }
}

$SkipAzureDevOpsMigrationTool = (  `
    $SkipMigrateTeams -and  `
    $SkipMigrateTestVariables -and  `
    $SkipMigrateTestConfigurations -and  `
    $SkipMigrateTestPlansAndSuites -and  `
    $SkipMigrateWorkItemQuerys -and  `
    $SkipMigrateBuildPipelines -and  `
    $SkipMigrateReleasePipelines -and  `
    $SkipMigrateVariableGroups -and  `
    $SkipMigrateTfsAreaAndIterations -and  `
$SkipMigrateWorkItems
)


if($martinConfigFileChanged) {
    $martinConfiguration | ConvertTo-Json -depth 32 | Set-Content $DevOpsMigrationToolConfigurationFile
}
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
    -SourcePAT $configuration.SourceProject.PersonalAccessToken `
    -SourceProcessId $configuration.SourceProject.ProcessTypeId `
    -TargetOrgName $configuration.TargetProject.OrgName `
    -TargetProjectName $TargetProjectName `
    -TargetPAT $configuration.TargetProject.PersonalAccessToken `
    -TargetProcessId $configuration.TargetProject.ProcessTypeId `
    -ProjectPath $projectPath `
    -ProjectDirectory "$ProjectDirectory\\$ScriptDirectoryName" `
    -WorkItemMigratorDirectory $WorkItemMigratorDirectory `
    -DevOpsMigrationToolConfigurationFile $DevOpsMigrationToolConfigurationFile `
    -SkipMigrateGroups $SkipMigrateGroups `
    -SkipMigrateBuildQueues $SkipMigrateBuildQueues `
    -SkipMigrateRepos $SkipMigrateRepos `
    -SkipMigrateWikis $SkipMigrateWikis `
    -SkipMigrateServiceHooks $SkipMigrateServiceHooks `
    -SkipMigratePolicies $SkipMigratePolicies `
    -SkipMigrateDashboards $SkipMigrateDashboards `
    -SkipAzureDevOpsMigrationTool $SkipAzureDevOpsMigrationTool `
    -SkipAddADOCustomField $SkipAddADOCustomField
#endregion
