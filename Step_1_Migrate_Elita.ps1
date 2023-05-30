Write-Host " "
Write-Host "Step 1 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateBuildQueues $FALSE `
-SkipMigrateRepos $FALSE `
-SkipMigrateWikis $FALSE `
-SkipMigrateServiceConnections $FALSE