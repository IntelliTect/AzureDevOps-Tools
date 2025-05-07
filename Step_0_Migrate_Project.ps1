
Param (
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "-------------------------------------------"
Write-Host "    Begin Project Migration    "    
Write-Host "-------------------------------------------"

# Best to do a user migration first since all of the other items can reference users and groups 

<#
  Step #1 migrate 
    - Build Queues (Project Agent Pools)
      - Build Environments done with Build Queues
    - Repositories
    - Wikis
    - Service Connections 
#>
& .\Step_1_Migrate_Project.ps1 -WhatIf $WhatIf

<#
  Step #3 migrate 
    - Work Items (Including 'Test Cases')
      In batches where Created Date Between
             0 -  100
           100 -  200 
           200 -  300 
           300 -  400 
           400 -  500 
           500 -  600 
           600 -  700
           800 -  800
           800 -  900
           900 - 1000
          1000 - 1100
          1100 - 1200
          1200 - 1300
          1300 - 1500
          1500 - 3000
          3000 +     

    Since the Azure REST API for work items has a query limit if 20,000, calls to the API have been broken up into batches based on the Work item's Created Date field 
    Each batch is listed below with the expected work item count to be migrated. The work item counts may vary since the work items are being updated daily. 
#>
& .\Step_3_Migrate_Project.ps1 -WhatIf $WhatIf

<#
  Step #2 migrate 
    - Areas and Iterations
    - Teams
    - Work Item Querys
    - Variable Groups
    - Build Pipelines
    - Release Pipelines
    - Task Groups
#>
& .\Step_2_Migrate_Project.ps1 -WhatIf $WhatIf



<#
  Step #4 migrate 
    - Groups
    - Test Configurations
    - Test Variables
    - Test Plans and Suites
    - Service Hooks 
    - Policies
    - Dashboards
    - Delivery Plans 
#>
& .\Step_4_Migrate_Project.ps1 -WhatIf $WhatIf

<#
  Step #5 migrate 
    - Artifacts 
#>
& .\Step_5_Migrate_Project.ps1 -WhatIf $WhatIf


Write-Host "------------------------------------------------"
Write-Host "    Completed Project MIgration     "    
Write-Host "------------------------------------------------"

