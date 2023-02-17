class ADO_IterationPath {
    [String]$Name
    [ADO_IterationPath[]]$Children
    
    ADO_IterationPath(
        [String]$name,
        [ADO_IterationPath[]]$children
    ) {
        $this.Name = $name
        $this.Children = $children
    }
}

function Start-ADOIterationPathsMigration {
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
        Write-Log -Message '-----------------------------'
        Write-Log -Message '-- Migrate Iteration Paths --'
        Write-Log -Message '-----------------------------'
        Write-Log -Message ' '

        $iterationPaths = Get-IterationPaths `
            -ProjectName $SourceProjectName `
            -OrgName $SourceOrgName `
            -Headers $SourceHeaders

        Push-IterationPaths `
            -ProjectName $TargetProjectName `
            -OrgName $TargetOrgName `
            -IterationPaths $iterationPaths `
            -Headers $TargetHeaders
    }
}

function ConvertTo-IterationPathObject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Object]$IterationPath
    )
    if ($PSCmdlet.ShouldProcess($IterationPath.Name)) {
        $ADOIterationPath = [ADO_IterationPath]::new($IterationPath.Name, [ADO_IterationPath[]]@())

        if ($IterationPath.hasChildren) {
            foreach ($child in $IterationPath.Children) {
                $ADOIterationPath.Children += (ConvertTo-AreaPathObject -IterationPath $child)
            }
        }

        return $ADOIterationPath
    }
}

function Get-IterationPaths {
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
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes/Iterations?`$depth=$Depth&api-version=6.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        [ADO_IterationPath[]]$iterationPaths = @()

        foreach ($result in $results.Children) {
            $iterationPaths += (ConvertTo-IterationPathObject -IterationPath $result)
        }

        return $iterationPaths
    }
}

function Push-IterationPaths {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [ADO_IterationPath[]]$IterationPaths,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $targetIterationPaths = Get-IterationPaths -ProjectName $ProjectName -OrgName $OrgName -Headers $Headers

        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes/Iterations?api-version=6.0"

        foreach ($iterationPath in $IterationPaths) {
            if ($null -ne ($targetIterationPaths | Where-Object { $_.Name -ieq $iterationPath.Name } )) {
                Write-Log -Message "Iteration path [$($iterationPath.Name)] already exists in target.. "
                continue
            }
            
            $body = $iterationPath | ConvertTo-Json
            Invoke-RestMethod -Method POST -Uri $url -Body $body -Headers $headers -ContentType "application/json"
        }
    }
}