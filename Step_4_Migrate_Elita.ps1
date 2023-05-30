Write-Host " "
Write-Host "Step 4 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateGroups $FALSE `
-SkipMigrateServiceHooks $FALSE `
-SkipMigratePolicies $FALSE `
-SkipMigrateDashboards $FALSE `
-SkipMigratDeliveryPlans $FALSE
