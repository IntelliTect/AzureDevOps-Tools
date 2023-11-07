
function Start-ADOServiceConnectionsMigration {
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
        Write-Log -Message '---------------------------------------------'
        Write-Log -Message '-- Migrate Service Connections (Endpoints) --'
        Write-Log -Message '---------------------------------------------'
        Write-Log -Message ' '

        # $sourceProject = Get-ADOProjects -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders 
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders 
        
        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $sourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $sourceHeaders
        
        #$sourceEndpoints | ConvertTo-Json -Depth 10 | Out-File -FilePath "DEBUG_endpoints.json"
        
        foreach ($endpoint in $sourceEndpoints) {
        
            if ($null -ne ($targetEndpoints | Where-Object {$_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($endpoint.id.ToUpper())")})) {
                Write-Log -Message "Service endpoint [$($endpoint.id)] already exists in target.. "
                continue
            }

            if ($null -ne ($targetEndpoints | Where-Object {($_.name -eq $endpoint.name) -and ($_.type -eq $endpoint.type)})) {
                Write-Log -Message "Service endpoint [$($endpoint.name)] [$($endpoint.id)] already exists in target.. "
                continue
            }

            Write-Log -Message "Attempting to create [$($endpoint.name)] in target.. "

            $projectReference = @{
                "id"        = $targetProject.id
                "name"      = $TargetProjectName
            }

            $endpointProjectReference = @{
                "name"              = $endpoint.name
                "description"       = ""
                "projectReference"  = $projectReference
            }

            $endpoint.serviceEndpointProjectReferences = @($endpointProjectReference)
        
            if($endpoint.data.creationMode -eq "Automatic") {
                if($null -ne $endpoint.data.azureSpnRoleAssignmentId){
                    $endpoint.data.azureSpnRoleAssignmentId = $null
                }
                $endpoint.data.azureSpnPermissions = $null
                $endpoint.data.spnObjectId = $null
                $endpoint.data.appObjectId = $null
                $endpoint.authorization.parameters.serviceprincipalid = $NULL
                if($NULL -ne $endpoint.authorization.parameters.authenticationType) {
                    $endpoint.authorization.parameters.authenticationType = $NULL
                }
            }

            # provide default values for specified endpoint types 
            if ($endpoint.type -eq "github") {
                $parameters = @{
                    "accesstoken" = "0123456789" 
                }
                $endpoint.authorization | Add-Member -NotePropertyName parameters -NotePropertyValue $parameters
            } elseif ($endpoint.type -eq "azurerm") {
                # Azurerm Service Connection types will need to be edited after migration to adhere to org/project naming conventions.
                if($endpoint.data.creationMode -eq "Automatic") {
                    if($null -ne $endpoint.data.azureSpnRoleAssignmentId){
                        $endpoint.data.azureSpnRoleAssignmentId = $null
                    }
                    $endpoint.data.azureSpnPermissions = $null
                    $endpoint.data.spnObjectId = $null
                    $endpoint.data.appObjectId = $null
                    $endpoint.authorization.parameters.serviceprincipalid = $NULL
                    if($NULL -ne $endpoint.authorization.parameters.authenticationType) {
                        $endpoint.authorization.parameters.authenticationType = $NULL
                    }
                } elseif($endpoint.data.creationMode -eq "Manual") {
                    Write-Log -Message "Service endpoints of type `"azurerm`" with a creationMode of `"Manual`" cannot be migrated as is .. "
                    Write-Log -Message "setting the  creationMode to `"Automatic`", this will need to be updated manually after migration.. "

                    $endpoint.data.creationMode = "Automatic"
                    $endpoint.authorization.parameters.serviceprincipalid = $NULL
                    if($NULL -ne $endpoint.authorization.parameters.authenticationType) {
                        $endpoint.authorization.parameters.authenticationType = $NULL
                    }
                }

            } elseif ($endpoint.type -eq "externaltfs") {
                $parameters = @{
                    "apitoken" = "0123456789" 
                }
                $endpoint.authorization | Add-Member -NotePropertyName parameters -NotePropertyValue $parameters
            } elseif ($endpoint.type -eq "stormrunner") {
                 $endpoint.authorization.parameters.username = "abcdefghij"
                 $endpoint.authorization.parameters | Add-Member -NotePropertyName password -NotePropertyValue "0123456789" 
            } elseif ($endpoint.type -eq "OctopusEndpoint") {
                $parameters = @{
                    "apitoken" = "0123456789" 
                }
                $endpoint.authorization | Add-Member -NotePropertyName parameters -NotePropertyValue $parameters
            } elseif ($endpoint.type -eq "sonarqube") {
                $parameters = @{
                    "username" = "abcdefghij"
                }
                $endpoint.authorization | Add-Member -NotePropertyName parameters -NotePropertyValue $parameters
            }

            try {
                New-ServiceEndpoint -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $targetHeaders -ServiceEndpoint $endpoint
                Write-Log -Message "Done!" -LogLevel SUCCESS
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
}


# Get ALl Service Connection Endpoints
function Get-ServiceEndpoints([string]$OrgName, [string]$ProjectName, $Headers) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?includeFailed=true&includeDetails=true&api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    
    return , $results.value
}

# Create NEW Service Connection Endpoint
function New-ServiceEndpoint([string]$OrgName, [string]$ProjectName, $Headers, $ServiceEndpoint) {

    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?api-version=7.0"
    
    $body = $ServiceEndpoint | ConvertTo-Json -Depth 32

    $results = Invoke-RestMethod -ContentType "application/json" -Method Post -uri $url -Headers $Headers -Body $body 
    
    return $results

}


