Param (
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Step 1 Migrate"
Write-Host "    - Build Queues (Project Agent Pools)"
Write-Host "    - Build Environments done with Build Queues"
Write-Host "    - Repositories"
Write-Host "    - Wikis"
Write-Host "    - Service Connections"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateBuildQueues $WhatIf `
-SkipMigrateRepos $WhatIf `
-SkipMigrateWikis $WhatIf `
-SkipMigrateServiceConnections $WhatIf