class ADO_Team {
    [String]$Id
    [String]$Name
    [String]$Description
    
    ADO_Team(
        [String]$id,
        [String]$name,
        [String]$description
    ) {
        $this.Id = $id
        $this.Name = $name
        $this.Description = $description
    }
}

function Start-ADOTeamsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$SourceProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$SourceOrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$SourceHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$TargetOrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$TargetHeaders
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate teams from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-------------------'
        Write-Log -Message '-- Migrate Teams --'
        Write-Log -Message '-------------------'
        Write-Log -Message ' '

        $teams = Get-ADOProjectTeams `
            -Headers $SourceHeaders `
            -OrgName $SourceOrgName `
            -ProjectName $SourceProjectName

        Push-ADOTeams `
            -Headers $TargetHeaders `
            -OrgName $TargetOrgName `
            -ProjectName $TargetProjectName `
            -Teams $teams
    }
}

function Get-ADOProjectTeams {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $FALSE)]
        [String]$TeamDisplayName
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        $url = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName/teams?api-version=6.0"
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

        [ADO_Team[]]$teams = @()
        foreach ($result in $results.value) {
            $teams += [ADO_Team]::new($result.id, $result.name, $result.description)
        }

        if ($TeamDisplayName) {
            return $teams | Where-Object { $_.Name -eq $TeamDisplayName }
        }
        return $teams
    }
}
function Push-ADOTeams {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [ADO_Team[]]$Teams
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        $targetTeams = Get-ADOProjectTeams `
            -Headers $Headers `
            -OrgName $OrgName `
            -ProjectName $ProjectName

        foreach ($team in $Teams) {
            if ($null -ne ($targetTeams | Where-Object { $_.Name -ieq $team.Name } )) {
                Write-Log -Message "Team [$($team.Name)] already exists in target.. "
                continue
            }
            New-ADOTeam `
                -Headers $Headers `
                -OrgName $OrgName `
                -ProjectName $ProjectName `
                -Team $team
            
        }
    }
}

function New-ADOTeam {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [ADO_Team]$Team
    )
    if ($PSCmdlet.ShouldProcess("$org/$ProjectName")) {
        $url = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName/teams?api-version=6.0"
    
        $body = @{
            "name"        = $Team.Name
            "description" = $Team.Description
        } | ConvertTo-Json
    
        Invoke-RestMethod -Method Post -uri $url -Body $body -Headers $Headers -ContentType "application/json"
    }
}