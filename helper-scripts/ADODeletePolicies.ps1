
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$FALSE)] [bool]$DoDelete = $TRUE,
        [Parameter (Mandatory=$FALSE)] [Object[]]$PolicyIds = $()
)

Write-Host "Begin Delete ALL Policies for Organization and Project"

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

 
Write-Host "Begin Deleting ALL Policies found in ($OrgName/$ProjectName)... "
Write-Host " "


# Get all policies for the process/project
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/policy/configurations?api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$policyConfigurations = $results.Value

$policies
if ($PolicyIds.Count -gt 0) {
        $policies = $policyConfigurations | Where-Object { $_.Id -in $PolicyIds }
        Write-Host "Begin Deleting set Policies with Ids $(ConvertTo-json -Depth 100 $PolicyIds)... "

} else {
        $policies = $policyConfigurations
        Write-Host "Begin Deleting ALL Policies found in ($OrgName/$ProjectName)... "
}

foreach ($policy in $policies) {
        try {
                Write-Log -Message "Deleting Policy with policy type display name: '$($policy.type.displayName)' and id: [$($policy.id)].. "
                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/policy/configurations/$($policy.id)?api-version=7.0"

                if($DoDelete) {
                        Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
                } else {
                        Write-Log -Message "TESTING - Test call to delete Policy with policy type display name: '$($policy.type.displayName)' and id: [$($policy.id)]"
                }
        }
        catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                try {
                        Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
                } catch {}
        }
}

Write-Host "End Deleting ALL Policies found in ($OrgName/$ProjectName)... "


