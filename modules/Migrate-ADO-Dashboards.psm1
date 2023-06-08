
function Start-ADODashboardsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,         # Not Needed?
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT          # Not Needed?
        
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Dashboards from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '------------------------'
        Write-Log -Message '-- Migrate Dashboards --'
        Write-Log -Message '------------------------'
        Write-Log -Message ' '


        $sourceTeams = [array](Get-Teams -orgName $SourceOrgName -projectName $SourceProjectName -headers $SourceHeaders)
        $targetTeams = [array](Get-Teams -orgName $TargetOrgName -projectName $TargetProjectName -headers $TargetHeaders)

        $sourceDashboards = Get-Dashboards -orgName $SourceOrgName -projectName $SourceProjectName -headers $SourceHeaders
        $targetDashboards = Get-Dashboards -orgName $TargetOrgName -projectName $TargetProjectName -headers $TargetHeaders

        $completed_list = New-Object Collections.Generic.List[string]

        :teamsLoop foreach ($team in $sourceTeams) {
            Write-Log -Message "--- Team Dashboard: $($team.Name) ---"
            $dashboards = Get-Dashboards -orgName $SourceOrgName -projectName $SourceProjectName -team $team.name -headers $SourceHeaders
           
            :dashboardLoop foreach ($dashboard in $dashboards) { 
                Write-Log -Message "Team: $($team.name) Dashboard: $($dashboard.name) DashboardScope: $($dashboard.dashboardScope)"

                $targetTeam = $targetTeams | Where-Object { $_.Name -eq $team.name }
                if($NULL -eq $targetTeam) {
                    Write-Log -Message "Dashboard [$($dashboard.Name) ($($dashboard.Id))] cannot be migrated. It is a project_Team dashboard and the Team [$team.name] does not exist in the Target project.. "
                }

                $targetDashboard = $targetDashboards | Where-Object { ($_.Name -eq $dashboard.name.Trim()) -and ($_.groupId -eq $targetTeam.Id) }
                $fullSourceDashboard = Get-Dashboard -orgName $SourceOrgName -projectName $SourceProjectName -team $team.name -dashboardId $dashboard.Id -headers $SourceHeaders

                if ($null -ine $targetDashboard) {
                    Write-Log -Message "Dashboard [$($targetDashboard.Name) ($($targetDashboard.Id))] already exists in target.. "

                    $fullTargetDashboard = Get-Dashboard -orgName $TargetOrgName -projectName $TargetProjectName -team $team.name -dashboardId $targetDashboard.Id -headers $TargetHeaders
                    
                    # See if the widgets for the Dashboard are migrated.. 
                    if($fullTargetDashboard.Widgets.Count -lt $fullSourceDashboard.Widgets.Count) {

                        try {
                            $fullTargetDashboard.Widgets = $fullSourceDashboard.Widgets
                            Write-Log -Message "Updating Dashboard Widgets for [$($fullTargetDashboard.Name)] in target.. "
                            Edit-Dashboard -orgName $targetOrgName -projectName $TargetProjectName -team $targetTeam.Id -headers $TargetHeaders -dashboard $fullTargetDashboard
                        }
                        catch {
                            Write-Log -Message "FAILED!" -LogLevel ERROR
                            Write-Log -Message $_.Exception -LogLevel ERROR
                            try {
                                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                            } catch {}
                        }
                    }
                    $completed_list.Add($dashboard.Name)
                    continue
                }

                try {
                    Write-Log -Message "CREATING Dashboard [$($dashboard.Name)] in target.. "

                    $payload = @{
                        "name"              = $fullSourceDashboard.name.Trim()
                        "description"       = $fullSourceDashboard.description
                        "dashboardScope"    = $fullSourceDashboard.dashboardScope
                        "position"          = $fullSourceDashboard.position
                        "widgets"           = $fullSourceDashboard.widgets
                        "refreshInterval"   = $fullSourceDashboard.refreshInterval
                        "url"               = $fullSourceDashboard.url
                    }

                    New-Dashboard -orgName $targetOrgName -projectName $TargetProjectName -team $team.name -headers $TargetHeaders -dashboard $payload

                    $completed_list.Add($dashboard.Name)
                } catch {
                    Write-Log -Message "FAILED!" -LogLevel ERROR
                    Write-Log -Message $_.Exception -LogLevel ERROR
                    try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                    } catch {}
                }

                # # THIS IS TEMP FOR TESTING SO THAT ONLY ONE DASHBOARD IS MIGRATED WHILE TESTING 
                # exit teamsLoop

            }
        }


        # Add Dashboards not tied to a Team
        $projectDashboards = $sourceDashboards | Where-Object { $_.Name -notin $completed_list }
        $targetDashboards = Get-Dashboards -orgName $TargetOrgName -projectName $TargetProjectName -headers $TargetHeaders
        Write-Log -Message "--- Project Dashboards: ---"
        ForEach ($dashboard in $projectDashboards) { 
            Write-Log -Message "dashboard: $($dashboard.name) dashboard scope: $($dashboard.dashboardScope)"

            $targetDashboard = $targetDashboards | Where-Object { ($_.Name -eq $dashboard.name.Trim()) -and ($_.Position -eq $dashboard.position) }
            if($targetDashboard.Count -gt 1){
                Write-Log -Message "Multiple Dashboards found with name [$($targetDashboard.Name)] in target, widgets will need to be manually migrated or ensure that dashboard names are unique.. "
            }
            $fullSourceDashboard = Get-Dashboard -orgName $SourceOrgName -projectName $sourceProjectName -dashboardId $dashboard.Id -headers $SourceHeaders

            if($SourceDashboard.Name -ne "") {
                Write-Log -Message "Dashboards with name [$($targetDashboard.Name)] was not found with Team Dashboards and has a dashboard scope of project_Team."
                Write-Log -Message "Something is wrong with this dashboard and will need to be migrated manually.."
                continue
            }

            if ($null -ine $targetDashboard) {
                Write-Log -Message "Dashboard [$($targetDashboard.Name) ($($targetDashboard.Id))] already exists in target.. "

                $fullTargetDashboard = Get-Dashboard -orgName $TargetOrgName -projectName $TargetProjectName -dashboardId $targetDashboard.Id -headers $TargetHeaders
                
                # See if the widgets for the Dashboard are migrated.. 
                if($fullTargetDashboard.Widgets.Count -lt $fullSourceDashboard.Widgets.Count) {
                    $fullTargetDashboard.Widgets = $fullSourceDashboard.Widgets
                    Write-Log -Message "Updating Dashboard Widgets for [$($fullTargetDashboard.Name)] in target.. "
                    Edit-Dashboard -orgName $targetOrgName -projectName $TargetProjectName -headers $TargetHeaders -dashboard $fullTargetDashboard
                }
                continue
            }
            
            try {
                Write-Log -Message "CREATING Dashboard [$($dashboard.Name)] in target.. "
                
                $payload = @{
                    "name"              = $fullSourceDashboard.name.Trim()
                    "description"       = $fullSourceDashboard.description
                    "dashboardScope"    = $fullSourceDashboard.dashboardScope
                    "position"          = $fullSourceDashboard.position
                    "widgets"           = $fullSourceDashboard.widgets
                    "refreshInterval"   = $fullSourceDashboard.refreshInterval
                    "url"               = $fullSourceDashboard.url
                }
                
                # TODO: One Dashboard is still Erroring due to one of the Widgets
                # if($dashboard.Name -eq "Policy Admin - Team Dashboard") {
                #     # $payload.widgets = $fullSourceDashboard.widgets[0..($fullSourceDashboard.widgets.Length-4)]
                #     $payload.widgets = @()
                #     $newDashboard = New-Dashboard -orgName $targetOrgName -projectName $targetProjectName -headers $targetHeaders -dashboard $payload
                #     Edit-DashboardWidgets -sourceWidgets $fullSourceDashboard.widgets -TargetOrgName $TargetOrgName -TargetProjectName $TargetProjectName -TargetHeaders $TargetHeaders -dashboard $newDashboard
                # }

                New-Dashboard -orgName $targetOrgName -projectName $targetProjectName -headers $targetHeaders -dashboard $payload
                $completed_list.Add($dashboard.Name)

            } catch {
               Write-Log -Message "FAILED!" -LogLevel ERROR
               Write-Log -Message $_.Exception -LogLevel ERROR
               try {
                   Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
               } catch {}
           }
        }
        Write-Log ' '
    }
}


# Dashboards
function Get-Dashboards([string]$orgName, [string]$projectName, [string]$team, $headers) {
    if ($team) {
        $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }
    else {
        $url = "https://dev.azure.com/$orgName/$projectName/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }
    
    
    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results.Value
}

function Get-Dashboard([string]$orgName, [string]$projectName, [string]$team, [string]$dashboardId, $headers) {
    if ($team) {
        $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards/$($dashboardId)?api-version=7.0-preview.3"
    }
    else {
        $url = "https://dev.azure.com/$orgName/$projectName/_apis/dashboard/dashboards/$($dashboardId)?api-version=7.0-preview.3"
    }

    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results
}


function New-Dashboard([string]$orgName, [string]$projectName, [string]$team, $headers, $dashboard) {
    if ($team) {
        $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }
    else {
        $url = "https://dev.azure.com/$orgName/$projectName/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }

    $body = $dashboard | ConvertTo-Json -Depth 100
    
    try {
        $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results
}

function Edit-Dashboard([string]$orgName, [string]$projectName, [string]$team, $headers, $dashboard) {
    if ($team) {
        $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards/$($dashboard.Id)?api-version=7.0-preview.3"
    }
    else {
        $url = "https://dev.azure.com/$orgName/$projectName/_apis/dashboard/dashboards/$($dashboard.Id)?api-version=7.0-preview.3"
    }

    $body = $dashboard | ConvertTo-Json -Depth 100
    
    try {
        $results = Invoke-RestMethod -Method PUT -uri $url -Headers $headers -Body $body -ContentType "application/json"
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results
}



# Teams
function Get-Teams([string]$orgName, [string]$projectName, $headers) {
    $url = "https://dev.azure.com/$orgName/_apis/projects/$projectName/teams?api-version=7.0"
    
    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results.Value
}


# Widgets
function Edit-DashboardWidgets ([Object[]]$SourceWidgets, [string]$TargetOrgName, [string]$TargetProjectName, $TargetHeaders, $Dashboard) {
    foreach ($widget in $SourceWidgets) { 
        try {
            Write-Log -Message "CREATING Widget [$($widget.Name) for Dashboard [$($Dashboard.Name)] in target.. "

            $newWidget = @{
                "name"                                = $widget.name
                "_links"                              = $widget._links	
                "allowedSizes"                        = $widget.allowedSizes	
                "areSettingsBlockedForUser"	          = $widget.areSettingsBlockedForUser
                "artifactId"                          = $widget.artifactId	
                "configurationContributionId"         = $widget.configurationContributionId	
                "configurationContributionRelativeId" = $widget.configurationContributionRelativeId	
                "contentUri"                          = $widget.contentUri
                "contributionId"                      = $widget.contributionId	
                "eTag"	                              = $widget.eTag
                "isEnabled"	                          = $widget.isEnabled
                "isNameConfigurable"                  = $widget.isNameConfigurable	
                "lightboxOptions"	                  = $widget.nalightboxOptionsme
                "Lightbox configuration"              = $widget.configuration
                "loadingImageUrl"	                  = $widget.loadingImageUrl
                "position"	                          = $widget.position
                "settings"	                          = $widget.settings
                "settingsVersion"                     = $widget.settingsVersion	
                "size"	                              = $widget.size
                "typeId"                              = $widget.typeId
                "url"	                              = $widget.url
            }

            New-Widget -OrgName $targetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders -DashboardId $Dashboard.id -widget $newWidget

        } catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
            } catch {}
        }
    }

    return 
}

# function Edit-DashboardWidgets ([string]$SourceOrgName, [string]$SourceProjectName, [string]$TargetOrgName, [string]$TargetProjectName, $SourceHeaders, $TargetHeaders, $SourceDashboard, $TargetDashboard) {
    
#     $sourceWidgets = $NULL
#     if($SourceDashboard.dashboardScope -eq "project_Team") {
#         $sourceTeam = $SourceDashboard.groupId
#         $sourceWidgets = Get-Widgets -OrgName $SourceOrgName -ProjectName $SourceProjectName -Team $sourceTeam -DashboardId $SourceDashboard.id -Headers $SourceHeaders
#     } else {
#         $sourceWidgets = Get-Widgets -OrgName $SourceOrgName -ProjectName $SourceProjectName -dashboardId $SourceDashboard.id -Headers $SourceHeaders
#     }

#     if($NULL -eq $sourceWidgets) {
#         Write-Log -Message "Unable to find source widgets for Org: $SourceOrgName Project: $sourceProjectName Team: $team Dashboard: $SourceDashboard.Name"
#         return
#     }

#     $targetWidgets = $NULL
#     $targetTeam = $NULL
#     if($TargetDashboard.dashboardScope -eq "project_Team") {
#         $targetTeam = $TargetDashboard.groupId
#         $targetWidgets = Get-Widgets -OrgName $TargetOrgName -ProjectName $TargetProjectName -Team $targetTeam -DashboardId $TargetDashboard.id -Headers $TargetHeaders
#     } else {
#         $targetWidgets = Get-Widgets -OrgName $TargetOrgName -ProjectName $TargetProjectName -DashboardId $TargetDashboard.id, -Headers $TargetHeaders
#     }

#     foreach ($widget in $sourceWidgets) { 
#         Write-Log -Message "team: $($team.name) dashboard: $($dashboard.name) widget: $($widget.Name)"

#         $targetWidget = $targetWidgets | Where-Object { $_.Name -eq $widget.Name }

#         if ($null -ine $targetWidget) {
#             Write-Log -Message "Widget [$($widget.Name) for Dashboard $($dashboard.Name)] already exists in target.. " 
#             continue
#         }

#         try {
#             Write-Log -Message "CREATING Widget [$($widget.Name) for Dashboard [$($dashboard.Name)] in target.. "

#             New-Widget -OrgName $targetOrgName -ProjectName $targetProjectName -Team $targetTeam -DashboardId $TargetDashboard.id -Headers $targetHeaders -widget @{
#                 "name"              = $dashboard.name
#                 "description"       = $dashboard.description
#             }

#         } catch {
#             Write-Log -Message "FAILED!" -LogLevel ERROR
#             Write-Log -Message $_.Exception -LogLevel ERROR
#             try {
#                 Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
#             } catch {}
#         }
#     }

#     return 
# }

function Get-Widgets([string]$OrgName, [string]$ProjectName, [string]$Team, [string]$DashboardId, $Headers) {
    if ($team) {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/$Team/_apis/dashboard/dashboards/$DashboardId/widgets?api-version=7.0-preview.2"
    }
    else {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/dashboard/dashboards/$DashboardId/widgets?api-version=7.0-preview.2"
    }
    
    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results.Value
}


function New-Widget([string]$OrgName, [string]$ProjectName, [string]$Team, [string]$DashboardId, $Headers, $Widget) {

    "https://dev.azure.com/$OrgName/$ProjectName/$Team/_apis/dashboard/dashboards/$DashboardId/widgets?api-version=7.0-preview.2"

    if ($team) {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/$Team/_apis/dashboard/dashboards/$DashboardId/widgets?api-version=7.0-preview.2"
    }
    else {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/dashboard/dashboards/$DashboardId/widgets?api-version=7.0-preview.2"
    }

    $body = $Widget | ConvertTo-Json -Depth 100
    
    try {
        $results = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    }
    catch {
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log  $_
    }
    
    return $results
}







