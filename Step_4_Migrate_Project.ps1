Param (
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Step 4 Migrate:"
Write-Host "   - Test Cases"
Write-Host "   - Groups"
Write-Host "   - Test Configurations"
Write-Host "   - Test Variables"
Write-Host "   - Test Plans and Suites"
Write-Host "   - Service Hooks"
Write-Host "   - Policies"
Write-Host "   - Dashboards"
Write-Host "   - Delivery Plans "
Write-Host " "
Write-Host " "

Write-Host " "
Write-Host "Migrate Test Cases via Martin's Tool"
Write-Host " "


& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $WhatIf `
-SkipAddReflectedWorkItemIdField $WhatIf `
-WorkItemQueryBit "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @TeamProject AND [System.WorkItemType] IN ('Test Case')"


Write-Host " "
Write-Host "Migrate Test Configurations, Test Variables, Test Plans and Suites via Martin's Tool"
Write-Host " "


& .\MigrateProject.ps1 `
-SkipMigrateTestConfigurations $WhatIf `
-SkipMigrateTestVariables $WhatIf `
-SkipMigrateTestPlansAndSuites $WhatIf `


Write-Host " "
Write-Host "Migrate Groups, Service hooks, Policies, Dashboards, and Delivery Plans"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateGroups $WhatIf `
-SkipMigrateServiceHooks $WhatIf `
-SkipMigratePolicies $WhatIf `
-SkipMigrateDashboards $WhatIf `
-SkipMigrateDeliveryPlans $WhatIf
