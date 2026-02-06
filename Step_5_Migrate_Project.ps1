Param (
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Step 5 Migrate:"
Write-Host "    - Artifacts "
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateArtifacts $WhatIf