
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

        $rootNode = Get-ClassificationNodes `
            -ProjectName $SourceProjectName `
            -OrgName $SourceOrgName `
            -Headers $SourceHeaders

        if ($rootNode) {
            New-ClassificationNodesRecursive `
                -ProjectName $TargetProjectName `
                -OrgName $TargetOrgName `
                -Nodes $rootNode.Children `
                -Headers $TargetHeaders

            Write-Log -Message "Migration of areas complete."
        }
        else {
            Write-Log -Message "No area paths to migrate in project $SourceProjectName"
        }
    }
}

function Start-ADOIterationsMigration {
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
            "Migrate iterations from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '------------------------'
        Write-Log -Message '-- Migrate Iterations --'
        Write-Log -Message '------------------------'
        Write-Log -Message ' '
    

        $sourceIterations = Get-ClassificationNodes -OrgName $SourceOrgName -ProjectName $SourceProjectName `
            -Headers $SourceHeaders -ClassificationNodeType Iterations
    
        Write-Log -Message "Migrating $($sourceIterations.Children.Count) iterations."

        New-ClassificationNodesRecursive -OrgName $TargetOrgName -ProjectName $TargetProjectName `
            -ClassificationNodeType Iterations -Headers $TargetHeaders -Nodes $sourceIterations.Children

        Write-Log -Message "Migration of iterations complete."
    }
}

function Get-ClassificationNodes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [Int]$Depth = 100,

        [Parameter(Mandatory = $False)]
        [ValidateSet("Areas", "Iterations")]
        [String]$ClassificationNodeType = "Areas"
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes" `
            + "/$($ClassificationNodeType)?`$depth=$Depth&api-version=5.0-preview.2"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

        return $results
    }
}

function New-ClassificationNodesRecursive {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        $Nodes,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $False)]
        [ValidateSet("Areas", "Iterations")]
        [String]$ClassificationNodeType = "Areas",

        [String]
        $ParentPath
    )
    
    foreach ($n in $Nodes) {
        $node = @{
            "name" = $n.name
        }

        if ($ClassificationNodeType -eq "Iterations") {
            $node["attributes"] = $n.attributes
        }
                
        $newNode = New-ClassificationNode -ProjectName $ProjectName -OrgName $OrgName `
            -Headers $Headers -Node $node -ParentPath $ParentPath `
            -ClassificationNodeType $ClassificationNodeType

        if ($n.Children.count -gt 0) {

            New-ClassificationNodesRecursive -ProjectName $ProjectName -OrgName $OrgName `
                -Headers $Headers -Nodes $n.Children -ParentPath $newNode.path `
                -ClassificationNodeType $ClassificationNodeType
        }
    }
}

function New-ClassificationNode {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [hashtable]$Node,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $False)]
        [ValidateSet("Areas", "Iterations")]
        [String]$ClassificationNodeType = "Areas",

        [String]
        $ParentPath
    )
    try {
        $paths = ""
    
        if ($ParentPath) {
            $singular = $ClassificationNodeType.Substring(0, $ClassificationNodeType.Length - 1)
            $paths = $ParentPath.Substring($ParentPath.LastIndexOf($singular) + $singular.Length).Replace("\", "/").Replace(" ", "%20")
        }
    
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/wit/classificationnodes/$($ClassificationNodeType)$($paths)?api-version=6.0"
        $body = $Node | ConvertTo-Json -Depth 32
    
        $result = Invoke-RestMethod -Method POST -Uri $url -Body $body -Headers $headers `
            -ContentType "application/json"

        Write-Log -Message "$($result.path) added to $($ClassificationNodeType)"
    }
    catch {
        Write-Log -Message "Unable to migrate area: $($Node.name)" -LogLevel ERROR
        Write-Log -Message $_.Exception -LogLevel ERROR
        Write-Log -Message $_ -LogLevel ERROR
        Write-Log -Message " "
    }
    
    return $result
}

function Remove-AllClassificationNodes {
    param (
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter(Mandatory = $False)]
        [ValidateSet("Areas", "Iterations")]
        [String]$ClassificationNodeType = "Areas"
    )
    
    $nodes = Get-ClassificationNodes -ProjectName $ProjectName -OrgName $OrgName `
        -Headers $Headers -ClassificationNodeType $ClassificationNodeType

    foreach ($a in $nodes.Children) {
        try {
            $url = "https://dev.azure.com/$($OrgName)/$($ProjectName)/_apis/wit/classificationnodes/$($ClassificationNodeType)/$($a.name)?api-version=7.1"
    
            Invoke-RestMethod -Method Delete -Uri $url -Headers $Headers
            
            Write-Log -Message "Node: $($a.name) deleted from $($ClassificationNodeType)"
        }
        catch {
            Write-Log -Message "FAILED!" -LogLevel ERROR
            Write-Log -Message $_.Exception -LogLevel ERROR
            Write-Log -Message ($_ | ConvertFrom-Json -Depth 10) -LogLevel ERROR
            Write-Log -Message $_ -LogLevel ERROR
            Write-Log -Message " "
        }
    }
}

