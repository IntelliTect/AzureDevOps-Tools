Param (
        [Parameter (Mandatory = $FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Step 2 Migrate:"
Write-Host "    - Areas and Iterations"
Write-Host "    - Teams"
Write-Host "    - Work Item Querys"
Write-Host "    - Variable Groups"
Write-Host "    - Build Pipelines"
Write-Host "    - Release Pipelines"
Write-Host "    - Task Groups"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
        -SkipMigrateTfsAreaAndIterations $WhatIf `
        -SkipMigrateTeams $WhatIf `
        -SkipMigrateWorkItemQuerys $WhatIf `
        -SkipMigrateVariableGroups $WhatIf `
        -SkipMigrateBuildPipelines $WhatIf `
        -SkipMigrateReleasePipelines $WhatIf `
        -SkipMigrateServiceConnections $WhatIf 