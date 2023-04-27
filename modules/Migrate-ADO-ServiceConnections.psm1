
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

        # $sourceProject = Get-ADOProjects -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders 
        # $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders 
        
        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $sourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $sourceHeaders
        
        #$sourceEndpoints | ConvertTo-Json -Depth 10 | Out-File -FilePath "DEBUG_endpoints.json"
        
        foreach ($endpoint in $sourceEndpoints) {
        
            if ($null -ne ($targetEndpoints | Where-Object {$_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($endpoint.id.ToUpper())")})) {
                Write-Log -Message "Service endpoint [$($endpoint.id)] already exists in target.. "
                continue
            }
        
            Write-Log -Message "Attempting to create [$($endpoint.name)] in target.. "
        
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
                New-ServiceEndpoint -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $targetHeaders -ServiceEndpoint $data
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
            }
        }
    }
}



function Get-ServiceEndpoints([string]$OrgName, [string]$ProjectName, $Headers) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    
    return , $results.value
}

function Get-ServiceEndpoint([string]$OrgName, [string]$ProjectName, $Headers, $ServiceEndpointId) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints/$ServiceEndpointId?api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
    
    return $results
}

function New-ServiceEndpoint([string]$OrgName, [string]$ProjectName, $Headers, $ServiceEndpoint) {

    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?api-version=7.0"
    
    $body = $ServiceEndpoint | ConvertTo-Json

    $results = Invoke-RestMethod -ContentType "application/json" -Method Post -uri $url -Headers $Headers -Body $body 
    
    return $results

}


