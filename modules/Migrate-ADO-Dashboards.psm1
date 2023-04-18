
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

        # set-alias CopyDashboard "C:\wrk\ups\azure-devops-utils\CopyDashboard\CopyDashboard\bin\Debug\netcoreapp3.1\CopyDashboard.exe"

        $teams = [array](Get-Teams -projectName $sourceProjectName -orgName $SourceOrgName -headers $SourceHeaders)

        ForEach ($team in $teams) {
            Write-Log -Message "--- Dashboard: ---"
            $dashboardResults = Get-Dashboards -projectName $sourceProjectName -orgName $SourceOrgName -team $team.name -headers $SourceHeaders
            if ($SourceOrgName.Contains("tfs")) {
                $dashboards = $dashboardResults.dashboardEntries;
            }
            else {
                $dashboards = $dashboardResults.value;
            }
            ForEach ($dashboard in $dashboards) { 
                Write-Log -Message "team: $($team.name) dashboard: $($dashboard.name) scope: copy$($dashboard.dashboardScope)"

                $targetDashboard = Get-Dashboard -projectName $targetProjectName -orgName $TargetOrgName -team $team.name -headers $TargetHeaders
                if ($null -ine $targetDashboard) {
                    Write-Log -Message "Dashboard [$($dashboard.Name)] already exists in target.. "
                    continue
                }

               New-Dashboard -projectName $targetProjectName -orgName $targetOrgName -team $team.name -headers $targetHeaders -dashboard @{
                    "name"              = $dashboard.name
                    "description"       = $dashboard.description
                    "dashboardScope"    = $dashboard.dashboardScope
                    "position"          = $dashboard.position
                    "widgets"           = $dashboard.widgets
                    "refreshInterval"   = $dashboard.refreshInterval
                    "url"               = $dashboard.url
                }
            }
        }
    }
}

