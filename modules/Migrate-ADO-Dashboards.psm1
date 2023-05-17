
function Start-ADODashboardsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT
        
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


        $sourceTeams = [array](Get-Teams -projectName $sourceProjectName -orgName $SourceOrgName -headers $SourceHeaders)

        $sourceDashboards = (Get-Dashboards -orgName $SourceOrgName -projectName $sourceProjectName -headers $SourceHeaders).Value
        $targetDashboards = (Get-Dashboard -orgName $TargetOrgName -projectName $targetProjectName -headers $TargetHeaders).Value

        $completed_list = New-Object Collections.Generic.List[string]

        ForEach ($team in $sourceTeams) {
            Write-Log -Message "--- Team Dashboard: ---"
            $dashboardResults = Get-Dashboards -orgName $SourceOrgName -projectName $sourceProjectName -team $team.name -headers $SourceHeaders
           
            if ($SourceOrgName.Contains("tfs")) {
                $dashboards = $dashboardResults.dashboardEntries;
            }
            else {
                $dashboards = $dashboardResults.value;
            }

            ForEach ($dashboard in $dashboards) { 
                Write-Log -Message "team: $($team.name) dashboard: $($dashboard.name) scope: copy$($dashboard.dashboardScope)"

                # $targetDashboard = Get-Dashboard -projectName $targetProjectName -orgName $TargetOrgName -team $team.name -headers $TargetHeaders
                $targetDashboard = $targetDashboards | Where-Object { $_.Name -eq $dashboard.name }

                if ($null -ine $targetDashboard) {
                    Write-Log -Message "Dashboard [$($dashboard.Name)] already exists in target.. "
                    continue
                }

                try{
                    Write-Log -Message "CREATING Dashboard [$($dashboard.Name)] in target.. "
                    New-Dashboard -orgName $targetOrgName -projectName $targetProjectName -team $team.name -headers $targetHeaders -dashboard @{
                        "name"              = $dashboard.name
                        "description"       = $dashboard.description
                        "dashboardScope"    = $dashboard.dashboardScope
                        "position"          = $dashboard.position
                        "widgets"           = $dashboard.widgets
                        "refreshInterval"   = $dashboard.refreshInterval
                        "url"               = $dashboard.url
                    }
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
        Write-Log -Message "--- Project Dashboards: ---"
        ForEach ($dashboard in $projectDashboards) { 
            Write-Log -Message "dashboard: $($dashboard.name) scope: copy$($dashboard.dashboardScope)"

            if ($null -ne ($targetDashboards | Where-Object { $_.name -ieq $dashboard.name } )) {
                Write-Log -Message "Dashboard [$($dashboard.Name)] already exists in target.. "
                continue
            }
            
            try {
                Write-Log -Message "CREATING Dashboard [$($dashboard.Name)] in target.. "
                $completed_list.Add($dashboard.Name)
                New-Dashboard -orgName $targetOrgName -projectName $targetProjectName -team $team.name -headers $targetHeaders -dashboard @{
                    "name"              = $dashboard.name
                    "description"       = $dashboard.description
                    "dashboardScope"    = $dashboard.dashboardScope
                    "position"          = $dashboard.position
                    "widgets"           = $dashboard.widgets
                    "refreshInterval"   = $dashboard.refreshInterval
                    "url"               = $dashboard.url
                }
            } catch {
               Write-Log -Message "FAILED!" -LogLevel ERROR
               Write-Log -Message $_.Exception -LogLevel ERROR
               try {
                   Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
               } catch {}
           }
        }

        Write-Log ''
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
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}

function Get-Dashboard([string]$orgName, [string]$projectName, [string]$team, $headers) {
    $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards?api-version=7.0-preview.3"

    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}


function New-Dashboard([string]$orgName, [string]$projectName, [string]$team, $headers, $dashboard) {
    if ($team) {
        $url = "https://dev.azure.com/$orgName/$projectName/$team/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }
    else {
        $url = "https://dev.azure.com/$orgName/$projectName/_apis/dashboard/dashboards?api-version=7.0-preview.3"
    }

    $body = $dashboard | ConvertTo-Json -Depth 10
    
    $results = Invoke-RestMethod -Method Post -uri $url -Headers $headers -Body $body -ContentType "application/json"
    
    return $results
}



# Teams
function Get-Teams([string]$projectName, [string]$orgName, $headers) {
    $url = "https://dev.azure.com/$orgName/_apis/projects/$projectName/teams?api-version=7.0&`$top=1000"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results.value
}