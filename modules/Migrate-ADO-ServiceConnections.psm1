
function Start-ADOServiceConnectionsMigration {
    # Start-ADOServiceEndpointsMigration
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
            "Migrate Service Endpoints from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '-------------------------------'
        Write-Log -Message '-- Migrate Service Endpoints --'
        Write-Log -Message '-------------------------------'
        Write-Log -Message ' '

        $sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
        $targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName
        
        $endpoints = Get-ServiceEndpoints -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders
        
        $targetEndpoints = Get-ServiceEndpoints -projectSk $TargetProject.id -org $SourceOrg -headers $sourceHeaders
        
        #$endpoints | ConvertTo-Json -Depth 10 | Out-File -FilePath "DEBUG_endpoints.json"
        
        foreach ($endpoint in $endpoints) {
        
            if ($null -ne ($targetEndpoints | Where-Object {$_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($endpoint.id.ToUpper())")})) {
                Write-Log -msg "Service endpoint [$($endpoint.id)] already exists in target.. "
                continue
            }
        
            Write-Log -msg "Attempting to create [$($endpoint.name)] in target.. "
        
            $data = @{
                "data"          = $endpoint.data
                "name"          = $endpoint.name
                "type"          = $endpoint.type
                "url"           = $endpoint.url
                "authorization" = $endpoint.authorization
                "description"   = "$($endpoint.description) #OriginServiceEndpointId:$($endpoint.id)"
                "isReady"       = $endpoint.isReady
            }
            
            try {
                New-ServiceEndpoint -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -serviceEndpoint $data
                Write-Log -msg "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -msg "FAILED!" -LogLevel ERROR
                Write-Log -msg ($_ | ConvertFrom-Json).message -LogLevel ERROR
            }
        }
    }
}

