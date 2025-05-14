
function Start-ADODashboardsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders
        
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
            }
        }


        # Add Dashboards not tied to a Team
        $projectDashboards = $sourceDashboards | Where-Object { $_.Name -notin $completed_list }
        $targetDashboards = Get-Dashboards -orgName $TargetOrgName -projectName $TargetProjectName -headers $TargetHeaders
        Write-Log -Message "--- Project Dashboards: ---"
        ForEach ($dashboard in $projectDashboards) { 
            Write-Log -Message "dashboard: $($dashboard.name) dashboard scope: $($dashboard.dashboardScope)"
            $MultipleDashboardsByName = $false


            $targetDashboard = $targetDashboards | Where-Object { ($_.Name -eq $dashboard.name.Trim()) -and ($_.Position -eq $dashboard.position) }
            if($targetDashboard.Count -gt 1){
                Write-Log -Message "Multiple Dashboards found with name [$($targetDashboard.Name)] in target, widgets will need to be manually migrated or ensure that dashboard names are unique.. "
                $MultipleDashboardsByName = $true
            }
            $fullSourceDashboard = Get-Dashboard -orgName $SourceOrgName -projectName $sourceProjectName -dashboardId $dashboard.Id -headers $SourceHeaders

            if($dashboard.dashboardScope -eq "project_Team") {
                Write-Log -Message "Dashboards with name [$($dashboard.Name)] was not found with Team Dashboards and has a dashboard scope of project_Team."
                Write-Log -Message "Something is wrong with this dashboard and will need to be migrated manually.."
                continue
            }
            
            if ($null -ine $targetDashboard) {
                Write-Log -Message "Dashboard [$($targetDashboard.Name) ($($targetDashboard.Id))] already exists in target.. "
                if(!$MultipleDashboardsByName) {
                    $fullTargetDashboard = Get-Dashboard -orgName $TargetOrgName -projectName $TargetProjectName -dashboardId $targetDashboard.Id -headers $TargetHeaders
                    
                    # See if the widgets for the Dashboard are migrated.. 
                    if($fullTargetDashboard.Widgets.Count -lt $fullSourceDashboard.Widgets.Count) {
                        Write-Log -Message "Mapping Dashboard Widget query Ids for [$($dashboard.Name)].. "
                        
                        $fullTargetDashboard.Widgets = $fullSourceDashboard.Widgets
                        Write-Log -Message "Updating Dashboard Widgets for [$($fullTargetDashboard.Name)] in target.. "
                        Edit-Dashboard -orgName $targetOrgName -projectName $TargetProjectName -headers $TargetHeaders -dashboard $fullTargetDashboard
                    }
                    continue
                } else {
                    # $TargetDashboard contains multiple dashboards with the same name since we have entered this else block
                    $matchingSourceDashboards = $projectDashboards | Where-Object { ($_.Name -eq $dashboard.name.Trim()) -and ($_.Position -eq $dashboard.position) }
                    $sourceDashboardIndex = $matchingSourceDashboards.IndexOf($dashboard)
                    $fullTargetDashboard = Get-Dashboard -orgName $TargetOrgName -projectName $TargetProjectName -dashboardId $($targetDashboard[$sourceDashboardIndex].Id) -headers $TargetHeaders 
                
                    if($fullTargetDashboard.Widgets.Count -lt $fullSourceDashboard.Widgets.Count) {
                        Write-Log -Message "Mapping Dashboard Widget query Ids for [$($fullTargetDashboard.Name)].. "
                        $fullTargetDashboard.Widgets = $fullSourceDashboard.Widgets
                        Write-Log -Message "Updating Dashboard Widgets for [$($fullTargetDashboard.Name)] with Source Dashboard Id [$($fullSourceDashboard.Id)] in target dashboard with Id [$($fullTargetDashboard.Id)] "
                        Edit-Dashboard -orgName $targetOrgName -projectName $TargetProjectName -headers $TargetHeaders -dashboard $fullTargetDashboard
                    }                    
                }
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
    Write-Log -Message "Updating Dashboard.."
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
