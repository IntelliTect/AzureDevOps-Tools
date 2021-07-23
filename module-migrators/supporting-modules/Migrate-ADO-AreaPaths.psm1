class ADO_AreaPath {
    [String]$Name
    [ADO_AreaPath[]]$Children
    
    ADO_AreaPath(
        [String]$name,
        [ADO_AreaPath[]]$children
    ) {
        $this.Name = $name
        $this.Children = $children
    }
}

function Start-ADOAreaPathsMigration {
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
            "Target project $TargetOrgName/$TargetProjectName",
            "Migrate area paths from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '------------------------'
        Write-Log -Message '-- Migrate Area Paths --'
        Write-Log -Message '------------------------'
        Write-Log -Message ' '

        $areaPaths = Get-AreaPaths `
            -ProjectName $SourceProjectName `
            -OrgName $SourceOrgName `
            -Headers $SourceHeaders

        Push-AreaPaths `
            -ProjectName $TargetProjectName `
            -OrgName $TargetOrgName `
            -AreaPaths $areaPaths `
            -Headers $TargetHeaders
    }
}

function ConvertTo-AreaPathObject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Object]$AreaPath
    )
    if ($PSCmdlet.ShouldProcess($AreaPath.Name)) {
        $ADOAreaPath = [ADO_AreaPath]::new($AreaPath.Name, [ADO_AreaPath[]]@())

        if ($AreaPath.hasChildren) {
            foreach ($child in $AreaPath.Children) {
                $ADOAreaPath.Children += (ConvertTo-AreaPathObject -AreaPath $child)
            }
        }

        return $ADOAreaPath
    }
}

function Get-AreaPaths {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [Int]$Depth = 100
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes/Areas?`$depth=$Depth&api-version=5.0-preview.2"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        [ADO_AreaPath[]]$areaPaths = @()

        foreach ($result in $results.Children) {
            $areaPaths += (ConvertTo-AreaPathObject -AreaPath $result)
        }

        return $areaPaths
    }
}

function Push-AreaPaths {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [ADO_AreaPath[]]$AreaPaths,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $targetAreaPaths = Get-AreaPaths -ProjectName $ProjectName -OrgName $OrgName -Headers $Headers
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes/Areas?api-version=6.0"

        foreach ($areaPath in $AreaPaths) {
            if ($null -ne ($targetAreaPaths | Where-Object { $_.Name -ieq $areaPath.Name } )) {
                Write-Log -Message "Area path [$($areaPath.Name)] already exists in target.. "
                continue
            }

            $body = $areaPath | ConvertTo-Json
            Invoke-RestMethod -Method POST -Uri $url -Body $body -Headers $headers -ContentType "application/json"
        }
    }
}