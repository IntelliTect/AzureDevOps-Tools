
Param (
        [Parameter (Mandatory=$FALSE)] [String]$NumberOfDays = "0",
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Work-Item back fill migration:"

Write-Host " "
Write-Host "Since the Azure REST API for work items has a query limit if 20,000, calls to the API may require the 'Number of Days Changed' value to be reduced to avoid pulling too many items"
Write-Host " "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 0 days Today and 'Number of Days Changed' ago"
Write-Host " "

& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $WhatIf `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - $($NumberOfDays) "



