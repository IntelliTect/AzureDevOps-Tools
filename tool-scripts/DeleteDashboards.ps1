
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT
)

Write-Host "Begin Delete ALL Dashboards for Organization and Project"

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

 
Write-Host "Begin Deleting ALL Dashboards found in ($OrgName/$ProjectName)... "
Write-Host " "


$url = "https://dev.azure.com/$OrgName/_apis/projects/$($ProjectName)?api-version=7.0"
$project = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$defaultTeam = $project.DefaultTeam.Id
Write-Log "Default Team ($defaultTeam)"

# Get all Dashboards for the process/project
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/dashboard/dashboards?api-version=7.0-preview.3"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$dashboards = $results.Value

foreach ($dashboard in $dashboards) {
        try {
                Write-Log -Message "Deleting Dashboard $($dashboard.Name) [$($dashboard.id)].. "

                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/dashboard/dashboards/$($dashboard.id)?api-version=7.0-preview.3"

                if($dashboard.dashboardScope -eq "project_Team") {
                        $team = $dashboard.groupId

                        if($defaultTeam -eq $team) {
                                continue
                        }
                        Write-Log "     Team ($team)"
                        $url = "https://dev.azure.com/$OrgName/$ProjectName/$team/_apis/dashboard/dashboards/$($dashboard.id)?api-version=7.0-preview.3"
                }

                Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }
}

Write-Host "End Deleting ALL Dashboards found in ($OrgName/$ProjectName)... "


