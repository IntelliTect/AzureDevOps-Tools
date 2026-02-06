
# ----------------------------------------------------------------------------------

$pat = $env:AZURE_DEVOPS_MIGRATION_PAT

# ----------------------------------------------------------------------------------
Write-Host "Begin Testing.."
Write-Host " "

$Headers = New-HTTPHeaders -PersonalAccessToken $PAT

try {
        $url = "https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.0"
        $result = Invoke-RestMethod -Method GET -uri $url -Headers $Headers 
        Write-Host ($result  | ConvertTo-Json -Depth 100)
} catch {
        Write-Log -Message "FAILED!" -LogLevel ERROR
        Write-Log -Message $_.Exception -LogLevel ERROR
        try { Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR } catch {}
}

Write-Host " "
Write-Host "End Testing.."
Write-Host " "