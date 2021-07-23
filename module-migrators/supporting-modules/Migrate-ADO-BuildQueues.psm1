class ADO_BuildQueue {
    [Int]$Id
    [String]$ProjectId
    [String]$Name
    [Boolean]$IsHosted
    [String]$PoolType
    
    ADO_BuildQueue(
        [Object]$object
    ) {
        $this.Id = $object.id
        $this.ProjectId = $object.projectId
        $this.Name = $object.pool.name
        $this.IsHosted = $object.pool.isHosted
        $this.PoolType = $object.pool.poolType
    }
}

function Start-ADOBuildQueuesMigration {
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
        Write-Log -Message '--------------------------'
        Write-Log -Message '-- Migrate Build Queues --'
        Write-Log -Message '--------------------------'
        Write-Log -Message ' '

        $queues = Get-BuildQueues `
            -ProjectName $SourceProjectName `
            -OrgName $SourceOrgName `
            -Headers $Sourceheaders

        Push-BuildQueues `
            -ProjectName $TargetProjectName `
            -OrgName $TargetOrgName `
            -Queues $queues `
            -Headers $TargetHeaders
    }
}

function Get-BuildQueues {
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
        $project = Get-ADOProjects -org $OrgName -Headers $Headers -ProjectName $ProjectName

        $url = "https://dev.azure.com/$OrgName/$($project.id)/_apis/distributedtask/queues?api-version=5.1-preview"
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    
        [ADO_BuildQueue[]]$queues = @()

        foreach ($result in $results.value) {
            $queues += [ADO_BuildQueue]::new($result)
        }

        return $queues
    }
}

function Push-BuildQueues {    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [ADO_BuildQueue[]]$queues,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $targetQueues = Get-BuildQueues -ProjectName $ProjectName -org $OrgName -headers $Headers

        foreach ($queue in $queues) {
            if ($queue.IsHosted -or $queue.Name -eq "Default") {
                continue
            }
        
            if ($null -ne ($targetQueues | Where-Object { $_.Name -ieq $queue.Name })) {
                Write-Log -Message "Build queue [$($queue.Name)] already exists in target.. "
                continue
            }
        
            Write-Log -Message "Attempting to create [$($queue.Name)] in target.. "
            try {
                New-BuildQueue -Headers $targetHeaders -ProjectName $ProjectName -OrgName $OrgName -Queue $queue
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -Message ($_ | ConvertFrom-Json).message ERROR
            }
        }
    }
}

function New-BuildQueue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)]
        [ADO_BuildQueue]$queue,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {
        $project = Get-ADOProjects -OrgName $OrgName -Headers $Headers -ProjectName $ProjectName

        $url = "https://dev.azure.com/$OrgName/$($project.id)/_apis/distributedtask/queues?api-version=5.1-preview&authorizePipelines=true"
    
        $body = @{
            "projectId" = $queue.ProjectId
            "name"      = $queue.Name
            "id"        = $queue.Id
        } | ConvertTo-Json

        $results = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    
        return $results
    }
}