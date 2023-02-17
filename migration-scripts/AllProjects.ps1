Import-Module Migrate-ADO -Force

# -------------------------------------------------------------------------------------
# -------------- Specifiy What Parts of the Migration Should Be Skipped --------------- 
#region -------------------------------------------------------------------------------
# Setting any of the below values to true will trigger a whatif condition rather than
# the actual migration.
[Boolean]$SKIP_MigrateOrgUsers = $FALSE
[Boolean]$SKIP_MigrateTeams = $FALSE
[Boolean]$SKIP_MigrateGroups = $FALSE
[Boolean]$SKIP_MigrateAreaPaths = $FALSE
[Boolean]$SKIP_MigrateIterationPaths = $FALSE
[Boolean]$SKIP_MigrateBuildQueues = $FALSE
[Boolean]$SKIP_MigrateRepos = $FALSE
[Boolean]$SKIP_MigrateWorkItems = $FALSE

# Validate the above configuration is okay
if (($SKIP_MigrateAreaPaths -or $SKIP_MigrateIterationPaths) -and !$SKIP_MigrateWorkItems) {
    throw "If you plan to migrate work items, then you need to migrate both the area and iteration paths for a project."
}
#endregion

# -------------------------------------------------------------------------------------
# ---------------- Set up files for logging & get configuration values ---------------- 
#region -------------------------------------------------------------------------------
$runDate = (get-date).ToString('yyyy-MM-dd HHmmss')
$configuration = [Object](Get-Content 'migration-scripts\Configuration.json' | Out-String | ConvertFrom-Json)

$projectPath = Get-ProjectFolderPath `
    -RunDate $runDate `
    -Root $configuration.ProjectDirectory

$env:MIGRATION_LOGS_PATH = $projectPath

$projects = Import-Csv $configuration.ProjectsCsv

$env:MIGRATION_LOGS_PATH = $projectPath

Set-ProjectFolders `
    -RunDate $runDate `
    -Projects $projects `
    -SourceOrg $configuration.SourceProject.OrgName `
    -SourcePAT $configuration.SourceProject.PAT `
    -TargetOrg $configuration.TargetProject.OrgName `
    -TargetPAT $configuration.TargetProject.PAT `
    -SavedAzureQuery $configuration.SavedAzureQuery `
    -MSConfigPath $configuration.MsConfigPath `
    -Root $configuration.ProjectDirectory
#endregion

# -------------------------------------------------------------------------------------
# ---------------- Start The Migration At the Org Level -------------------------------
#region -------------------------------------------------------------------------------
Write-Log -Message ' '
Write-Log -Message '------------------------------------------------------------------------------------------------'
Write-Log -Message "-- Migrate $($configuration.SourceProject.OrgName) to $($configuration.TargetProject.OrgName) --"
Write-Log -Message '------------------------------------------------------------------------------------------------'
Write-Log -Message ' '
 
# ========================================
# ====== Migrate Users On Org Level ====== 
#region ==================================    
Start-ADOUserMigration `
    -SourceOrgName $configuration.SourceProject.OrgName `
    -SourcePat $configuration.SourceProject.PAT `
    -TargetOrgName $configuration.TargetProject.OrgName `
    -TargetPAT $configuration.TargetProject.PAT `
    -WhatIf:$SKIP_MigrateOrgUsers
#endregion

# --------------------------------------------------------------------------------------
# ---------------- For each project in the CSV file - preform a migration --------------
#region --------------------------------------------------------------------------------
foreach ($project in $projects) {
    # Get project folder & set logging path w/ env variable
    $projectPath = Get-ProjectFolderPath `
        -RunDate $runDate `
        -SourceProject $project.SourceProject `
        -TargetProject $project.TargetProject `
        -Root $configuration.ProjectDirectory

    $env:MIGRATION_LOGS_PATH = $projectPath

    # Get Headers
    $sourceHeaders = New-HTTPHeaders `
        -PersonalAccessToken $configuration.SourceProject.PAT
    $targetHeaders = New-HTTPHeaders `
        -PersonalAccessToken $configuration.TargetProject.PAT

    Write-Log -Message ' '
    Write-Log -Message '--------------------------------------------------------------------'
    Write-Log -Message "-- Migrate $($project.sourceProject) to $($project.TargetProject) --"
    Write-Log -Message '--------------------------------------------------------------------'
    Write-Log -Message ' '

    # ========================================
    # ============ Migrate Teams =============
    #region ==================================
    Start-ADOTeamsMigration `
        -SourceHeaders $sourceHeaders `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceProjectName $project.SourceProject `
        -TargetHeaders $targetHeaders `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetProjectName $project.TargetProject `
        -WhatIf:$SKIP_MigrateTeams
    #endregion

    # ========================================
    # =========== Migrate Groups =============
    #region ==================================
    Start-ADOGroupsMigration `
        -SourcePAT $configuration.SourceProject.PAT `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceProjectName $project.SourceProject `
        -TargetPAT $configuration.TargetProject.PAT `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetProjectName $project.TargetProject `
        -WhatIf:$SKIP_MigrateGroups
    #endregion

    # ========================================
    # ========== Migrate Area Paths ==========
    #region ==================================
    Start-ADOAreaPathsMigration `
        -SourceProjectName $project.SourceProject `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $project.TargetProject `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SKIP_MigrateAreaPaths
    #endregion

    # ========================================
    # ======= Migrate Iteration Paths ========
    #region ==================================
    Start-ADOIterationPathsMigration `
        -SourceProjectName $project.SourceProject `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $project.TargetProject `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SKIP_MigrateIterationPaths
    #endregion

    # ========================================
    # ========= Migrate Build Queues =========
    #region ==================================
    Start-ADOBuildQueuesMigration `
        -SourceProjectName $project.SourceProject `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $project.TargetProject `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SKIP_MigrateBuildQueues
    #endregion

    # ========================================
    # ============ Migrate Repos =============
    #region ==================================
    Start-ADORepoMigration `
        -SourceProjectName $project.SourceProject `
        -SourceOrgName $configuration.SourceProject.OrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $project.TargetProject `
        -TargetOrgName $configuration.TargetProject.OrgName `
        -TargetHeaders $targetHeaders `
        -ReposPath $projectPath `
        -WhatIf:$SKIP_MigrateRepos
    #endregion

    # ========================================
    # ========== Migrate work items ==========
    #region ==================================
    if (!$SKIP_MigrateWorkItems) {
        $savedPath = $(Get-Location).Path
    
        Set-Location -Path $configuration.WorkItemMigratorDirectory
        dotnet run --validate "$projectPath\ProjectConfiguration.json"
        dotnet run --migrate "$projectPath\ProjectConfiguration.json"
    
        Set-Location -Path $savedpath
    }
    else {
        Write-Host "What if: Preforming the operation `"Migrate work items from source project $($project.SourceProject)`" on target `"Target project $($project.TargetProject)`""
    }
    #endregion

    # ========================================
    # ========== Migration Finished ========== 
    # ========================================
    Write-Log "Done migrating $($project.SourceProject) to $($project.TargetProject)" -LogLevel SUCCESS
}
#endregion
#endregion