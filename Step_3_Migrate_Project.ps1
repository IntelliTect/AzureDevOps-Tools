Write-Host " "
Write-Host "Step 3 Migrate GL.CL-Elita Project Migration"
Write-Host " "
Write-Host " "

# Since the Azure REST API for work items has a query limit if 20,000, calls to the API have been broken up into batches based on the Work item's Changed Date field 
# Each batch is listed below with the expected work item count to be migrated. The work item counts may since the work items are being updated daily. 
# 
# - Work Items
#    0 -   75 - 17284
#   75 -  200 - 19010
#  200 -  400 - 19159
#  400 -  575 - 18754
#  575 -  800 - 16754
#  800 - 1000 - 16190
# 1000 - 1150 - 13664
# 1150 - 2000 -  6897
# -------------------
# Rough Total - 127,712


Write-Host " "
Write-Host "Since the Azure REST API for work items has a query limit if 20,000, calls to the API have been broken up into batches based on the Work item's Changed Date field"
Write-Host " "

Write-Host " "
Write-Host "Migrate Work Items with Changed Date between Today and 75 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 75 AND [System.ChangedDate] <= @Today - 0 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 75 days ago and 200 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 200 AND [System.ChangedDate] <= @Today - 75 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 200 days ago and 400 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 400 AND [System.ChangedDate] <= @Today -200 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 400 days ago and 757 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 575 AND [System.ChangedDate] <= @Today - 400 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 575 days ago and 800 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 800 AND [System.ChangedDate] <= @Today - 575 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 800 days ago and 1000 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 1000 AND [System.ChangedDate] <= @Today - 800 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 1000 days ago and 1150 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 1150 AND [System.ChangedDate] <= @Today - 1000 "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 1150 days ago and 2000 days ago"
Write-Host " "
& .\MigrateProject.ps1 `
-SkipMigrateWorkItems $FALSE `
-WorkItemQueryBit "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') AND [System.ChangedDate] > @Today - 2000 AND [System.ChangedDate] <= @Today - 1150 "