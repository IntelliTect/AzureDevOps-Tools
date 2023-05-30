Write-Host " "
Write-Host "Step 2 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateTfsAreaAndIterations $FALSE `
-SkipMigrateTeams $FALSE `
-SkipMigrateTestVariables $FALSE `
-SkipMigrateTestConfigurations $FALSE `
-SkipMigrateTestPlansAndSuites $FALSE `
-SkipMigrateWorkItemQuerys $FALSE `
-SkipMigrateVariableGroups $FALSE `
-SkipMigrateBuildPipelines $FALSE `
-SkipMigrateReleasePipelines $FALSE `
-SkipMigrateTaskGroups $FALSE