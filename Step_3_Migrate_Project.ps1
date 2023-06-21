Write-Host " "
Write-Host "Step 3 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "

# Since the Azure REST API for work items has a query limit if 20,000, calls to the API have been broken up into batches based on the Work item's Changed Date field 
# Each batch is listed below with the expected work item count to be migrated. The work item counts may since the work items are being updated daily. 
# 


Write-Host " "
Write-Host "Since the Azure REST API for work items has a query limit if 20,000, calls to the API have been broken up into batches based on the Work item's Changed Date field"
Write-Host " "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 0 days ago and 100 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 100 AND [System.CreatedDate] <= @Today - 0 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 100 days ago and 200 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 200 AND [System.CreatedDate] <= @Today - 100 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 200 days ago and 300 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 300 AND [System.CreatedDate] <= @Today - 200 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 300 days ago and 400 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 400 AND [System.CreatedDate] <= @Today - 300 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 400 days ago and 500 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 500 AND [System.CreatedDate] <= @Today - 400 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 500 days ago and 600 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 600 AND [System.CreatedDate] <= @Today - 500 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 600 days ago and 700 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 700 AND [System.CreatedDate] <= @Today - 600 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 700 days ago and 800 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 800 AND [System.CreatedDate] <= @Today - 700 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 800 days ago and 900 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 900 AND [System.CreatedDate] <= @Today - 800 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 900 days ago and 1000 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 1000 AND [System.CreatedDate] <= @Today - 900 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 1000 days ago and 1100 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 1100 AND [System.CreatedDate] <= @Today - 1000 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 1100 days ago and 1200 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 1200 AND [System.CreatedDate] <= @Today - 1100 "


Write-Host " "
Write-Host "Migrate Work Items with Created Date between 1200 days ago and 5000 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.CreatedDate] > @Today - 5000 AND [System.CreatedDate] <= @Today - 1200 "




