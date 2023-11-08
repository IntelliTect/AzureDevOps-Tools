
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
  Step #3 migrate 
    - Work Items (Including 'Test Cases')
           0 -   75 - 17284
          75 -  200 - 19010
         200 -  400 - 19159
         400 -  575 - 18754
         575 -  800 - 16754
         800 - 1000 - 16190
        1000 - 2000 - 19821

#>
& .\Step_3_Migrate_Project.ps1 -WhatIf $WhatIf

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

