class ADO_BuildEnvironment {
    [String]$Name
    [String]$Description
    
    ADO_BuildEnvironment(
        [Object]$object
    ) {
        $this.Name = $object.name
        $this.Description = $object.description
    }
}

function Start-ADOBuildEnvironmentsMigration {
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
            "Migrate build queries from source project $SourceOrg/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '--------------------------------'
        Write-Log -Message '-- Migrate Build Environments --'
        Write-Log -Message '--------------------------------'
        Write-Log -Message ' '

        $environments = Get-BuildEnvironments `
            -ProjectName $SourceProjectName `
            -OrgName $SourceOrgName `
            -Headers $Sourceheaders

        Push-BuildEnvironments `
            -ProjectName $TargetProjectName `
            -OrgName $TargetOrgName `
            -Environments $environments `
            -Headers $TargetHeaders
    }
}

function Get-BuildEnvironments {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 
        
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $project = Get-ADOProjects -OrgName $OrgName -ProjectName $ProjectName -Headers $Headers 

        $url = "https://dev.azure.com/$OrgName/$($project.id)/_apis/distributedtask/environments?api-version=7.0"
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    
        [ADO_BuildEnvironment[]]$environments = @()

        foreach ($result in $results.value) {
            $environments += [ADO_BuildEnvironment]::new($result)
        }

        return $environments
    }
}

function Push-BuildEnvironments {    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [ADO_BuildEnvironment[]]$environments,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $targetEnvironments = Get-BuildEnvironments -ProjectName $ProjectName -org $OrgName -headers $Headers

        foreach ($environment in $environments) {
            if ($null -ne ($targetEnvironments | Where-Object { $_.Name -ieq $environment.Name })) {
                Write-Log -Message "Build environment [$($environment.Name)] already exists in target.. "
                continue
            }
        
            Write-Log -Message "Attempting to create [$($environment.Name)] in target.. "
            try {
                New-BuildEnvironment -Headers $targetHeaders -ProjectName $ProjectName -OrgName $OrgName -Environment $environment
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -Message ($_ | ConvertFrom-Json).message ERROR
            }
        }
    }
}

function New-BuildEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [ADO_BuildEnvironment]$environment,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $project = Get-ADOProjects -OrgName $OrgName -ProjectName $ProjectName -Headers $Headers

        $url = "https://dev.azure.com/$OrgName/$($project.id)/_apis/distributedtask/environments?api-version=7.0&authorizePipelines=true"
    
        $body = @{
            "name"          = $environment.Name
            "description"   = $environment.Description
        } | ConvertTo-Json

        $results = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    
        return $results
    }
}