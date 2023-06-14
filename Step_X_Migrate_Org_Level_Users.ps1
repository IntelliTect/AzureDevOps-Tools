Write-Host " "
Write-Host "Step Pre Migrate Organization users From AIZ-GL to AIZ-Global"
Write-Host " "
Write-Host " "


.\MigrateProject.ps1 `
-SkipMigrateOrganizationUsers $FALSE