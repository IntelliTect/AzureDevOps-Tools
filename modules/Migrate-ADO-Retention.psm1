function Start-ADORetentionMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders

    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate Retension from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '---------------------------------------------'
        Write-Log -Message '-- Migrate Retension --'
        Write-Log -Message '---------------------------------------------'
        Write-Log -Message ' '

        try {
            $sourceRetention = Get-Retention -OrgName $SourceOrgName -ProjectName `
                $SourceProjectName -Headers $SourceHeaders
    
            if ($sourceRetention) {
                Update-Retention -OrgName $TargetOrgName -ProjectName $TargetProjectName `
                    -Headers $TargetHeaders -Retention $sourceRetention

                Write-Log -Message "Retention Policy update for project $TargetProjectName"
            }
        }
        catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            Write-Log -Message $_ -LogLevel ERROR
            Write-Log -Message " "
        }
    }
}

function Get-Retention {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string]$OrgName,
        [Parameter(Mandatory = $TRUE)]
        [string]$ProjectName,
        [Parameter(Mandatory = $TRUE)]
        [hashtable]$Headers   
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/build/retention?api-version=7.1"

    $results = Invoke-RestMethod -Method Get -Uri $url -Headers $Headers

    return $results
}

function Update-Retention {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string]$OrgName,
        [Parameter(Mandatory = $TRUE)]
        [string]$ProjectName,
        [Parameter(Mandatory = $TRUE)]
        [hashtable]$Headers, 
        [Parameter(Mandatory = $TRUE)]
        $Retention
    )
    
    $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/build/retention?api-version=7.1"

    $wat = @{
        "artifactsRetention"           = $Retention.purgeArtifacts
        "pullRequestRunRetention"      = $Retention.purgePullRequestRuns
        "retainRunsPerProtectedBranch" = $Retention.retainRunsPerProtectedBranch
        "runRetention"                 = $Retention.purgeRuns
    }
    $body = $wat | ConvertTo-Json -Depth 32

    $results = Invoke-RestMethod -Method Patch -Uri $url -Headers $Headers `
        -Body $body -ContentType "application/json"

    return $results
}