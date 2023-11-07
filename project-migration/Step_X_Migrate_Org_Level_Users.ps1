Param (
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)


Write-Host " "
Write-Host " Migrate Organization Users"
Write-Host " from Source organization to Target organization"
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateOrganizationUsers $WhatIf