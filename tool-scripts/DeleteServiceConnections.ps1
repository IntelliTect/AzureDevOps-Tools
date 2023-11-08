
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT
)

Write-Host "Begin Delete ALL Service Connections for Organization and Project"

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

 
Write-Host "Begin Deleting ALL Service Connections found in ($OrgName/$ProjectName)... "
Write-Host " "

# Get project info
$url = "https://dev.azure.com/$OrgName/_apis/projects/$($ProjectName)?api-version=7.0"
$project = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

# Get all Service Connections for the process/project
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?includeFailed=true&includeDetails=true&api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$serviceConnections = $results.Value

foreach ($serviceConnection in $serviceConnections) {
        try {
                Write-Log -Message "Deleting Service Connections $($serviceConnection.Name) [$($serviceConnection.id)].. "

                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints/$($serviceConnection.id)?projectIds=$($project.id)&api-version=7.0"

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

Write-Host "End Deleting ALL Service Connections found in ($OrgName/$ProjectName)... "


