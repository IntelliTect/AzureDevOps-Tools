Using Module "..\modules\Migrate-ADO-Common.psm1"

Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$FALSE)] [bool]$DoDelete = $TRUE
)


Write-Host "Begin process to Delete ADO Library Variable Groups for Organization $OrgName and Project $ProjectName.."
Write-Host "Get ADO Library Variable Groups for Organization $OrgName and Project $ProjectName.."

# Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

$targetProject = Get-ADOProjects -OrgName $OrgName -ProjectName $ProjectName -Headers $headers

$url = "https://dev.azure.com/$orgName/$projectName/_apis/distributedtask/variablegroups?api-version=7.0"
$results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
$groups = $results.value


try {
        Write-Host "Begin Deleting ALL ADO Variable Groupss... "
        Write-Host " "
        foreach ($group in $groups) {
                try {
                        # Delete Group 
                        Write-Log -Message "Deleting ADO Variable Group `"$($group.name)`".. "
                        if($DoDelete -eq $TRUE) {
                                $d_url =  "https://dev.azure.com/$orgName/_apis/distributedtask/variablegroups/$($group.Id)?projectIds=$($targetProject.Id)&api-version=7.1-preview.2"
                                $results = Invoke-RestMethod -Method DELETE -uri $d_url -Headers $headers
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
}
catch {
        Write-Log -Message "FAILED!" -LogLevel ERROR
        Write-Log -Message $_.Exception -LogLevel ERROR
        try {
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
        } catch {}
}

Write-Host "End Deleting ALL ADO Library Variable Groups found in ($OrgName/$ProjectName)... "


