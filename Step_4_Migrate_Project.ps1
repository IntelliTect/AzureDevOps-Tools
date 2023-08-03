Write-Host " "
Write-Host "Step 4 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "


Write-Host " "
Write-Host "Migrate Test Configurations, Test Variables, Test Plans and Suites via Martin's Tool"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateTestConfigurations $FALSE `
-SkipMigrateTestVariables $FALSE `
-SkipMigrateTestPlansAndSuites $FALSE `


Write-Host " "
Write-Host "Migrate Groups, Service hooks, Policies, Dashbaords, and Delivery Plans"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateGroups $FALSE `
-SkipMigrateServiceHooks $FALSE `
-SkipMigratePolicies $FALSE `
-SkipMigrateDashboards $FALSE `
-SkipMigrateDeliveryPlans $FALSE
