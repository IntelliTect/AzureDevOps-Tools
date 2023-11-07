
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$FALSE)] [bool]$DoDelete = $TRUE
)


Write-Host "Begin process to Delete ADO Security Groups for Organization $OrgName and Project $ProjectName.."


Write-Host "Get ADO Security Groups for Organization $OrgName and Project $ProjectName.."
$organization = "https://dev.azure.com/$OrgName/"
Set-AzDevOpsContext -PersonalAccessToken $PAT -OrgName $OrgName -ProjectName $ProjectName
$groups = (az devops security group list --organization $organization --project $ProjectName --detect $false | ConvertFrom-Json).graphGroups

Write-Host "Begin Deleting ALL ADO Security Groups... "
Write-Host " "
foreach ($group in $groups) {
        try {
                # Delete Group 
                Write-Log -Message "Deleting ADO Security Group `"$($group.displayName)`" Group.. "
                if($DoDelete -eq $TRUE) {
                        az devops security group delete --id $group.descriptor --detect $FALSE --org $organization --yes
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

Write-Host "End Deleting ALL ADO Security Groups found in ($OrgName/$ProjectName)... "


