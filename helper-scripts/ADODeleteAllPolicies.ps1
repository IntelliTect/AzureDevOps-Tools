
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT
)

Write-Host "Begin Delete ALL Policied for Organization and Project"

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

 
Write-Host "Begin Deleting ALL Policies found in ($OrgName/$ProjectName)... "
Write-Host " "


# Get all policies for the process/project
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/policy/configurations?api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
$policies = $results.Value

foreach ($policy in $policies) {
        try {
                Write-Log -Message "Deleting Policy $($policy.type.displayName) [$($policy.id)].. "
                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/policy/configurations/$($policy.id)?api-version=7.0"
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

Write-Host "End Deleting ALL Policies found in ($OrgName/$ProjectName)... "


