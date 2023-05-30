<#
  AIZ-GL/GL.CL-Elita to AIZ-Global/GL.CL-Elita-Migrated migration 
#>
Write-Host " "
Write-Host "-------------------------------------------"
Write-Host "    Begin GL.CL-Elita Project Migration    "    
Write-Host "-------------------------------------------"

<#
  Step #1 migrate 
    - Build Queues (Project Agent Pools)
    - Repositories
    - Wikis
    - Service Connections 
#>
& .\Step_1_Migrate_Elita.ps1

<#
  Step #2 migrate 
    - Areas and Iterations
    - Teams
    - Test Variables
    - Test Configurations
    - Test Plans and Suites
    - Work Item Querys
    - Variable Groups
    - Build Pipelines
    - Release Pipelines
    - Task Groups
#>
& .\Step_2_Migrate_Elita.ps1

<#
  Step #3 migrate 
    - Work Items
           0 -   75 - 17284
          75 -  200 - 19010
         200 -  400 - 19159
         400 -  575 - 18754
         575 -  800 - 16754
         800 - 1000 - 16190
        1000 - 2000 - 19821

#>
& .\Step_3_Migrate_Elita.ps1

<#
  Step #4 migrate 
    - Groups
    - SErvice Hooks 
    - Policies
    - Dashbaords
    - Delivery Plans 
#>
& .\Step_4_Migrate_Elita.ps1

<#
  Step #5 migrate 
    - Artifacts 
#>
& .\Step_5_Migrate_Elita.ps1


Write-Host "------------------------------------------------"
Write-Host "    Completed GL.CL-Elita Project MIgration     "    
Write-Host "------------------------------------------------"

