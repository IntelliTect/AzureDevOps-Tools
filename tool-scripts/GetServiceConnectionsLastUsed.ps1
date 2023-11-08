
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT
)

Write-Host "Begin GET ALL Service Connections for Organization and Project"

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

 
Write-Host "Begin getting ALL Service Connections found in ($OrgName/$ProjectName)... "
Write-Host " "


# Get all Service Connections for the process/project
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?includeFailed=true&includeDetails=true&api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$serviceConnections = $results.Value

$output = @()
foreach ($serviceConnection in $serviceConnections) {
        try {
                Write-Log -Message "GET Service Connection history for $($serviceConnection.Name) [$($serviceConnection.id)].. "

                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/$($serviceConnection.id)/executionhistory?api-version=7.1-preview.1"

                $result = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
                $sc_history = $sc_history=$result.Value
                $sc_history_top = $sc_history | Sort-Object -Property { $_.data.startTime} -Descending | Select-Object -First 1

                $item = @{
                        "Id"                    = $serviceConnection.Id
                        "Name"                  = $serviceConnection.Name
                        "latestStartTime"       = $sc_history_top.data.startTime  
                }    

                $output += $item
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }
}

$output

Write-Host "End Deleting ALL Service Connections found in ($OrgName/$ProjectName)... "


