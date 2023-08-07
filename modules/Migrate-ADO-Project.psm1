
function Start-ADOProjectMigration {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName,
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT,
        [Parameter (Mandatory = $TRUE)] [String]$ProjectPath,
        [Parameter (Mandatory = $TRUE)] [String]$MartinsToolConfigurationFile,
        [Parameter (Mandatory = $TRUE)] [String]$WorkItemMigratorDirectory,
        [Parameter (Mandatory = $TRUE)] [String]$DevOpsMigrationToolConfigurationFile,
        [Parameter (Mandatory = $TRUE)] [String]$ArtifactFeedPackageVersionLimit,
        
        # -------------- What parts of the migration should NOT be executed --------------- 
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateGroups = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateBuildQueues = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateRepos = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateWikis = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceHooks = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigratePolicies = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDashboards = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateServiceConnections = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateArtifacts = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateDeliveryPlans = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipAzureDevOpsMigrationTool = $TRUE,
        [parameter(Mandatory=$FALSE)] [Boolean]$SkipMigrateOrganizationUsers = $TRUE
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate teams from source project $SourceOrg/$SourceProjectName")
    ) {
        
        # Get Headers
        $sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
        $targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT


        # -------------------------------------------------------------------------------------
        # ---------------- Start The Migration At the Org Level -------------------------------
        #region -------------------------------------------------------------------------------
        Write-Log -Message ' '
        Write-Log -Message '----------------------------------------------------'
        Write-Log -Message "-- From: $($SourceOrgName) To: $($TargetOrgName) --"
        Write-Log -Message '----------------------------------------------------'
        Write-Log -Message ' '


        # ========================================
        # ====== Migrate Users On Org Level ====== 
        #region ==================================    
        Start-ADOUserMigration `
        -SourceOrgName $SourceOrgName `
        -SourcePat $SourcePAT `
        -TargetOrgName $TargetOrgName `
        -TargetPAT $TargetPAT `
        -WhatIf: $SkipMigrateOrganizationUsers
        #endregion

       
        # -----------------------------------------------------------------------------------------
        # ---------------- Start The Migration At the Project Level -------------------------------
        #region -----------------------------------------------------------------------------------
        Write-Log -Message ' '
        Write-Log -Message '--------------------------------------------------------------------'
        Write-Log -Message "-- Migrate $($SourceProjectName) to $($TargetProjectName) --"
        Write-Log -Message '--------------------------------------------------------------------'
        Write-Log -Message ' '
        
        Write-Log -Message "SourceProjectName $($SourceProjectName)"
        Write-Log -Message "SourceOrgName $($SourceOrgName)"
        Write-Log -Message ' '
        Write-Log -Message "TargetProjectName $($TargetProjectName)"
        Write-Log -Message "TargetOrgName $($TargetOrgName)"
        Write-Log -Message ' '

        # ========================================
        # ========= Migrate Build Queues =========
        #       Migrate-ADO-BuildQueues.psm1
        #region ==================================
        Start-ADOBuildQueuesMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateBuildQueues
        #endregion

        # ==============================================
        # ========= Migrate Build Environments =========
        #       Migrate-ADO-BuildEnvironments.psm1
        #region ========================================
        Start-ADOBuildEnvironmentsMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -SourcePat $SourcePAT `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -TargetPAT $TargetPAT `
        -ReplacePipelinePermissions $TRUE `
        -WhatIf:$SkipMigrateBuildQueues
        #endregion

       
        

        # ========================================
        # ============ Migrate Repos =============
        #       Migrate-ADO-Repos.psm1
        #region ==================================
        Start-ADORepoMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -ReposPath $projectPath `
        -WhatIf:$SkipMigrateRepos
        #endregion

        # ========================================
        # ============ Migrate Wikis =============
        #       Migrate-ADO-Repos.psm1
        #region ==================================
        Start-ADOWikiMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -ReposPath $projectPath `
        -WhatIf:$SkipMigrateWikis
        #endregion
        
        # ========================================
        # ===== Migrate Service Connections ======
        #   Migrate-ADO-ServiceConnections.psm1
        #region ==================================
        Start-ADOServiceConnectionsMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateServiceConnections
        #endregion

        

        # ==========================================
        # ====== Azure DevOps Migration Tool  ======
        # ====== Martin's Tool                ======
        #region ====================================
        if (!$SkipAzureDevOpsMigrationTool) {
            $savedPath = $(Get-Location).Path
    
            Set-Location -Path $WorkItemMigratorDirectory

            # Migrate Work Items using nkdagility tool 
            Write-Log -Message "Run Azure DevOps Migration Tool (Martins Tool)"

            $arguments = "execute --config `"$MartinsToolConfigurationFile`""
            
            Start-Process -NoNewWindow -Wait -FilePath .\migration.exe -ArgumentList $arguments
        
            Set-Location -Path $savedpath
        } else {
            Write-Host "What if: Preforming the operation `"Running Azure DevOps Migration Tool Migration from source project $SourceProjectName`" on target `"Target project $TargetProjectName`""
        }
        #endregion

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
        # ======== Migrate Service Hooks =========
        #       Migrate-ADO-ServiceHooks.psm1
        # Repos must migrate before service hooks 
        #region ==================================
        # .\migrateServiceHooks.ps1 
        Start-ADOServiceHooksMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateServiceHooks
        # #endregion

        # ========================================
        # =========== Migrate Policies ===========
        #       Migrate-ADO-Policies.psm1
        #region ==================================
        # .\migratePolicies.ps1 
        Start-ADOPoliciesMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -SourcePAT $SourcePAT `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -TargetPAT $TargetPAT `
        -WhatIf:$SkipMigratePolicies
        # #endregion

        # ========================================
        # ========== Migrate Dashboards ==========
        #       Migrate-ADO-Dashboards.psm1
        #region ==================================
        # .\migrateDashboards.ps1 
        Start-ADODashboardsMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -WhatIf:$SkipMigrateDashboards
        # #endregion

        # ===========================================
        # ========== Migrate DeliveryPlans ==========
        #       Migrate-ADO-DeliveryPlans.psm1
        #region =====================================
        Start-ADODeliveryPlansMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -SourcePAT $SourcePAT `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -TargetPAT $TargetPAT `
        -WhatIf:$SkipMigrateDeliveryPlans
        # #endregion

        # ========================================
        # ========= Migrate Artifacts= ===========
        #       Migrate-ADO-Artifacts.psm1
        #region ==================================
        Start-ADOArtifactsMigration `
        -SourceOrgName $SourceOrgName `
        -SourceProjectName $SourceProjectName `
        -SourceHeaders $sourceHeaders `
        -SourcePAT $SourcePAT `
        -TargetOrgName $TargetOrgName `
        -TargetProjectName $TargetProjectName `
        -TargetHeaders $targetHeaders `
        -TargetPAT $TargetPAT `
        -ProjectPath $projectPath `
        -ArtifactFeedPackageVersionLimit $ArtifactFeedPackageVersionLimit `
        -WhatIf:$SkipMigrateArtifacts
        # #endregion

        # ========================================
        # ========== Migration Finished ========== 
        # ========================================
        Write-Log "Done migrating $($SourceProjectName) to $($TargetProjectName)" -LogLevel SUCCESS

    }
}
