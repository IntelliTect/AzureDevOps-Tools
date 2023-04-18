
function Start-ADOProjectMigration {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName,
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory = $TRUE)] [String]$SourceProcessId,
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT,
        [Parameter (Mandatory = $TRUE)] [String]$TargetProcessId,
        [Parameter (Mandatory = $TRUE)] [String]$ProjectPath,
        [Parameter (Mandatory = $TRUE)] [String]$ProjectDirectory,
        [Parameter (Mandatory = $TRUE)] [String]$WorkItemMigratorDirectory,
        [Parameter (Mandatory = $TRUE)] [String]$DevOpsMigrationToolConfigurationFile,
        # -------------- What parts of the migration should NOT be executed --------------- 
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateGroups = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildQueues = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateRepos = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWikis = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceHooks = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigratePolicies = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDashboards = $TRUE,
        # [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildDefinitions = $TRUE,
        # [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateReleaseDefinitions = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipAzureDevOpsMigrationTool = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipAddADOCustomField = $TRUE
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate teams from source project $SourceOrg/$SourceProjectName")
    ) {

        Write-Log -Message ' '
        Write-Log -Message '--------------------------------------------------------------------'
        Write-Log -Message "-- Migrate $($SourceProjectName) to $($TargetProjectName) --"
        Write-Log -Message '--------------------------------------------------------------------'
        Write-Log -Message ' '
        
        Write-Log -Message "SourceProjectName $($SourceProjectName)"
        Write-Log -Message "SourceOrgName $($SourceOrgName)"
        Write-Log -Message "SourceProcessId $($SourceProcessId)"
        Write-Log -Message ' '
        Write-Log -Message "TargetProjectName $($TargetProjectName)"
        Write-Log -Message "TargetOrgName $($TargetOrgName)"
        Write-Log -Message "TargetProcessId $($TargetProcessId)"
        Write-Log -Message ' '
        # IntelliTect AzureDevOps-Tools Items
        Write-Log -Message "SkipMigrateGroups $($SkipMigrateGroups)"
        Write-Log -Message "SkipMigrateBuildQueues $($SkipMigrateBuildQueues)"
        Write-Log -Message "SkipMigrateRepos $($SkipMigrateRepos)"
        Write-Log -Message "SkipMigrateWikis $($SkipMigrateWikis)"
        Write-Log -Message "SkipMigrateServiceHooks $($SkipMigrateServiceHooks)"
        Write-Log -Message "SkipMigrateVariableGroups $($SkipMigrateVariableGroups)"
        Write-Log -Message "SkipMigratePolicies $($SkipMigratePolicies)"
        Write-Log -Message "SkipMigrateDashboards $($SkipMigrateDashboards)"
        # Write-Log -Message "SkipMigrateBuildDefinitions $($SkipMigrateBuildDefinitions)"
        # Write-Log -Message "SkipMigrateReleaseDefinitions $($SkipMigrateReleaseDefinitions)"
        # Azure DevOps Migration Tool Items
        Write-Log -Message "SkipMigrateTeams $($SkipMigrateTeams)"
        Write-Log -Message "SkipMigrateTestVariables $($SkipMigrateTestVariables)"
        Write-Log -Message "SkipMigrateTestConfigurations $($SkipMigrateTestConfigurations)"
        Write-Log -Message "SkipMigrateTestPlansAndSuites $($SkipMigrateTestPlansAndSuites)"
        Write-Log -Message "SkipMigrateWorkItemQuerys $($SkipMigrateWorkItemQuerys)"
        Write-Log -Message "SkipMigrateBuildPipelines $($SkipMigrateBuildPipelines)"
        Write-Log -Message "SkipMigrateReleasePipelines $($SkipMigrateReleasePipelines)"
        Write-Log -Message "SkipMigrateTfsAreaAndIterations $($SkipMigrateTfsAreaAndIterations)"
        Write-Log -Message "SkipMigrateWorkItems $($SkipMigrateWorkItems)"
        Write-Log -Message ' '
        Write-Log -Message "SkipAddADOCustomField $($SkipAddADOCustomField)"
        Write-Log -Message ' '


           # Get Headers
        $sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
        $targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT


        # ========================================
        # =========== Migrate Groups =============
        #         Migrate-ADO-Groups.psm1
        #region ==================================
        Start-ADOGroupsMigration `
        -SourcePAT $SourcePAT `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -TargetPAT $TargetPAT `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -WhatIf:$SkipMigrateGroups
        #endregion

        # ========================================
        # ========= Migrate Build Queues =========
        #       Migrate-ADO-BuildQueues.psm1
        #region ==================================
        Start-ADOBuildQueuesMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateBuildQueues
        #endregion

        # ========================================
        # ============ Migrate Repos =============
        #       Migrate-ADO-Repos.psm1
        #region ==================================
        Start-ADORepoMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -ReposPath $projectPath `
        -WhatIf:$SkipMigrateRepos
        #endregion

        # ========================================
        # ============ Migrate Wikis =============
        #       Migrate-ADO-Repos.psm1
        #region ==================================
        Start-ADOWikiMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -ReposPath $projectPath `
        -WhatIf:$SkipMigrateWikis
        #endregion

        

        # # ========================================
        # # ======= Migrate Build Definitions ======
        # #    Migrate-ADO-BuildDefinitions.psm1 
        # #region ==================================
        # #
        # # *** INCOMPLETE SCRIPT
        # #
        # # .\migrateBuildDefinitions.ps1
        # Start-ADOBuildDefinitionsMigration `
        # -SourceProjectName $SourceProjectName `
        # -SourceOrgName $SourceOrgName `
        # -SourceHeaders $sourceHeaders `
        # -TargetProjectName $TargetProjectName `
        # -TargetOrgName $TargetOrgName `
        # -TargetHeaders $targetHeaders `
        # -WhatIf:$SkipMigrateBuildDefinitions
        # # #endregion

        # # ========================================
        # # ====== Migrate Release Definitions =====
        # #   Migrate-ADO-ReleaseDefinitions.psm1
        # #region ==================================
        # #
        # # *** INCOMPLETE SCRIPT
        # #
        # # .\migrateReleaseDefinitions.ps1
        # Start-ADOReleaseDefinitionsMigration `
        # -SourceProjectName $SourceProjectName `
        # -SourceOrgName $SourceOrgName `
        # -SourceHeaders $sourceHeaders `
        # -TargetProjectName $TargetProjectName `
        # -TargetOrgName $TargetOrgName `
        # -TargetHeaders $targetHeaders `
        # -WhatIf:$SkipMigrateReleaseDefinitions
        # # #endregion


        # ==========================================
        # ====== Azure DevOps Migration Tool  ======
        # ====== Martin's Tool                ======
        #region ====================================
        if (!$SkipAzureDevOpsMigrationTool) {
            # ======================================================
            # ========= Add Custom Field To Source Project ========= 
            #region ================================================
            Start-ADO_AddCustomField `
            -Headers $sourceHeaders `
            -OrgName $SourceOrgName `
            -PAT $SourcePAT `
            -ProjectName $SourceProjectName `
            -ProcessId $SourceProcessId `
            -FieldName "Custom.ReflectedWorkItemId" `
            -WhatIf: $SkipAddADOCustomField
            #endregion

            # ======================================================
            # ========= Add Custom Field To Target Project ========= 
            #region ================================================
            Start-ADO_AddCustomField `
            -Headers $targetHeaders `
            -OrgName $TargetOrgName `
            -PAT $targetPAT `
            -ProjectName $TargetProjectName `
            -ProcessId $TargetProcessId `
            -FieldName "Custom.ReflectedWorkItemId" `
            -WhatIf: $SkipAddADOCustomField
            #endregion


            $savedPath = $(Get-Location).Path
    
            Set-Location -Path $WorkItemMigratorDirectory

            # Migrate Work Items using nkdagility tool 
            Write-Log -Message "Run Azure DevOps Migration Tool (Martins Tool)"

            $arguments = "execute --config `"$ProjectDirectory\configuration-intellitect.json`""
            Start-Process -NoNewWindow -Wait -FilePath .\migration.exe -ArgumentList $arguments
        
            Set-Location -Path $savedpath
        } else {
            Write-Host "What if: Preforming the operation `"Running Azure DevOps Migration Tool Migration from source project $SourceProjectName`" on target `"Target project $TargetProjectName`""
        }
        #endregion


        # ========================================
        # ======== Migrate Service Hooks =========
        #       Migrate-ADO-ServiceHooks.psm1
        # Repos must migrate before service hooks 
        #region ==================================
        # .\migrateServiceHooks.ps1 
        Start-ADOServiceHooksMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateServiceHooks
        # #endregion

        # ========================================
        # =========== Migrate Policies ===========
        #       Migrate-ADO-Policies.psm1
        #region ==================================
        # .\migratePolicies.ps1 
        Start-ADOPoliciesMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigratePolicies
        # #endregion

        # ========================================
        # ========== Migrate Dashboards ==========
        #       Migrate-ADO-Dashboards.psm1
        #region ==================================
        # .\migrateDashboards.ps1 
        Start-ADODashboardsMigration `
        -SourceProjectName $SourceProjectName `
        -SourceOrgName $SourceOrgName `
        -SourceHeaders $sourceHeaders `
        -SourcePAT $SourcePAT `
        -TargetProjectName $TargetProjectName `
        -TargetOrgName $TargetOrgName `
        -TargetHeaders $targetHeaders `
        -TargetPAT $TargetPAT `
        -WhatIf:$SkipMigrateDashboards
        # #endregion


        # ========================================
        # ========== Migration Finished ========== 
        # ========================================
        Write-Log "Done migrating $($SourceProjectName) to $($TargetProjectName)" -LogLevel SUCCESS

    }
}
