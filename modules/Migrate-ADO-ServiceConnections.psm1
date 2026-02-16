
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

        $sourceProject = Get-ADOProjects -OrgName $SourceOrgName -ProjectName $SourceProjectName -Headers $SourceHeaders 
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $TargetHeaders 
        
        $sourceEndpoints = Get-ServiceEndpoints -OrgName $SourceOrgName -ProjectName $SourceProjectName  -Headers $SourceHeaders
        $targetEndpoints = Get-ServiceEndpoints -OrgName $TargetOrgName -ProjectName $TargetProjectName  -Headers $TargetHeaders
        
        #$sourceEndpoints | ConvertTo-Json -Depth 10 | Out-File -FilePath "DEBUG_endpoints.json"
        
        foreach ($endpoint in $sourceEndpoints) {
        
            if ($null -ne ($targetEndpoints | Where-Object { $_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($endpoint.id.ToUpper())") })) {
                Write-Log -Message "Service endpoint [$($endpoint.id)] already exists in target.. "
                continue
            }

            if ($null -ne ($targetEndpoints | Where-Object { ($_.name -eq $endpoint.name) -and ($_.type -eq $endpoint.type) })) {
                Write-Log -Message "Service endpoint [$($endpoint.name)] [$($endpoint.id)] already exists in target.. "
                continue
            }

            Write-Log -Message "Attempting to create [$($endpoint.name)] in target.. "

            $projectReference = @{
                "id"   = $targetProject.id
                "name" = $TargetProjectName
            }

            $endpointProjectReference = @{
                "name"             = $endpoint.name
                "description"      = ""
                "projectReference" = $projectReference
            }

            $endpoint.serviceEndpointProjectReferences = @($endpointProjectReference)

            # provide default values for specified endpoint types 
            if ($endpoint.type -eq "azurerm") {
                # Azurerm Service Connection types will need to be edited after migration to adhere to org/project naming conventions.
                if ($endpoint.authorization.scheme -eq "WorkloadIdentityFederation" -OR $endpoint.authorization.scheme -eq "ServicePrincipal") {
                    if ($endpoint.authorization.parameters.tenantId) {
                        Set-Parameters -Authorization $endpoint.authorization -MemberName `
                            "tenantid" -MemberValue $endpoint.authorization.parameters.tenantId
                    }
                    if ($endpoint.authorization.parameters.serviceprincipalId) {
                        Set-Parameters -Authorization $endpoint.authorization -MemberName `
                            "serviceprincipalId" -MemberValue $endpoint.authorization.parameters.serviceprincipalId
                    }
                    
                    # $endpoint.authorization.scheme = "WorkloadIdentityFederation"
                }
                elseif ($endpoint.authorization.scheme -eq "PublishProfile") {
                    Set-Parameters -Authorization $endpoint.authorization -MemberName "tenantid" -MemberValue $endpoint.authorization.tenantId
                    Set-Parameters -Authorization $endpoint.authorization -MemberName "resourceId" -MemberValue $endpoint.authorization.resourceId
                } 
                if ($endpoint.data.creationMode -eq "Automatic") {
                    if ($null -ne $endpoint.data.azureSpnRoleAssignmentId) {
                        $endpoint.data.azureSpnRoleAssignmentId = $null
                    }
                    $endpoint.data.azureSpnPermissions = $null
                    $endpoint.data.spnObjectId = $null
                    $endpoint.data.appObjectId = $null
                    $endpoint.authorization.parameters.serviceprincipalid = $NULL
                    
                }
                elseif ($endpoint.data.creationMode -eq "Manual") {
                    Write-Log -Message "Service endpoints of type `"azurerm`" with a creationMode of `"Manual`" cannot be migrated as is .. "
                    Write-Log -Message "setting the  creationMode to `"Automatic`", this will need to be updated manually after migration.. "

                    $endpoint.data.creationMode = "Automatic"
                    $endpoint.authorization.parameters.serviceprincipalid = $NULL
                } 
                if ($NULL -ne $endpoint.authorization.parameters.authenticationType) {
                    $endpoint.authorization.parameters.PSObject.Properties.Remove("authenticationType")
                }
            }
            elseif ($endpoint.authorization.scheme -eq "Token") {
                Set-Parameters -Authorization $endpoint.authorization -MemberName "apitoken" -MemberValue "Update-Please"
            }
            elseif ($endpoint.authorization.scheme -eq "OAuth") {
                Set-Parameters -Authorization $endpoint.authorization -MemberName "accessToken" -MemberValue "Update-Please"
            }
            elseif ($endpoint.authorization.scheme -eq "InstallationToken") {
                Set-Parameters -Authorization $endpoint.authorization -MemberName "IdSignature" -MemberValue $null
                Set-Parameters -Authorization $endpoint.authorization -MemberName "IdToken" -MemberValue $null
            }
            elseif ($endpoint.authorization.scheme -eq "UsernamePassword") {
                Set-Parameters -Authorization $endpoint.authorization -MemberName "username" -MemberValue "Update-Please"
                Set-Parameters -Authorization $endpoint.authorization -MemberName "password" -MemberValue "Update-Please"
            }

            try {
                $newEndpoint = New-ServiceEndpoint -OrgName $TargetOrgName -ProjectName $TargetProjectName -Headers $targetHeaders -ServiceEndpoint $endpoint
                Write-Log -Message "Done!" -LogLevel SUCCESS

                Start-ADOServiceConnectionRolesMigration -SourceProjectId $sourceProject.id `
                    -TargetProjectId $targetProject.id -SourceEndpointId $endpoint.id -TargetEndpointId $newEndpoint.id

            }
            catch {
                Write-Log -Message "FAILED!" -LogLevel ERROR
                Write-Log -Message $_.Exception -LogLevel ERROR
                Write-Log -Message $_ -LogLevel ERROR
                Write-Log -Message " "
            }
        }
    }
}

function Set-Parameters {
    param (
        [Parameter(Mandatory = $TRUE)]
        $Authorization,

        [Parameter(Mandatory = $TRUE)]
        [String]
        $MemberName,

        [Parameter(Mandatory = $TRUE)]
        [AllowNull()]
        $MemberValue
    )
    
    if ($Authorization.parameters) {
        if ($Authorization.parameters | Get-Member -Name $MemberName) {
            $Authorization.parameters.$MemberName = $MemberValue
        }
        else {
            $Authorization.parameters | Add-Member -NotePropertyName $MemberName -NotePropertyValue $MemberValue
        }
    }
    else {
        $parameters = [PSCustomObject]@{
            $MemberName = $MemberValue
        }

        $Authorization | Add-Member -NotePropertyName parameters -NotePropertyValue $parameters
    }
}


# Get ALl Service Connection Endpoints
function Get-ServiceEndpoints([string]$OrgName, [string]$ProjectName, $Headers) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?" `
        + "includeFailed=true&includeDetails=true&actionFilter=manage&api-version=7.0"
    
    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers
    
    return , $results.value
}

# Create NEW Service Connection Endpoint
function New-ServiceEndpoint([string]$OrgName, [string]$ProjectName, $Headers, $ServiceEndpoint) {

    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints?api-version=5.0-preview.2"
    
    $body = $ServiceEndpoint | ConvertTo-Json -Depth 32

    $results = Invoke-RestMethod -ContentType "application/json" -Method Post -uri $url -Headers $Headers -Body $body 
    
    return $results
}

function Start-ADOServiceConnectionRolesMigration {
    param(
        [Parameter(Mandatory = $TRUE)]
        [string] 
        $SourceProjectId, 
        [Parameter(Mandatory = $TRUE)]
        [string] 
        $TargetProjectId, 
        [Parameter(Mandatory = $TRUE)]
        [string]
        $SourceEndpointId,
        [Parameter(Mandatory = $TRUE)]
        [string]
        $TargetEndpointId
    )
    $sourceRoleAssignments = Get-RoleAssignments -OrgName $SourceOrgName -ProjectId $SourceProjectId `
        -EndpointId $SourceEndpointId -Headers $SourceHeaders
    $targetRoleAssignments = Get-RoleAssignments -OrgName $TargetOrgName -ProjectId $TargetProjectId `
        -EndpointId $TargetEndpointId -Headers $TargetHeaders

    foreach ($roleAssignment in $sourceRoleAssignments) {
        $roleName = $roleAssignment.identity.displayName.Replace($SourceProjectName, $TargetProjectName)

        $query = $targetRoleAssignments | Where-Object { $_.name -eq $roleName }

        if ($query) {
            Write-Log -Message "Service Connection Role: $($roleName) already exists."
            continue
        }

        try {
            Write-Log -Message "Attempting to create role assignment [$($roleName)] in target.. "

            $identities = Get-IdentitiesByName -OrgName $TargetOrgName -Headers $TargetHeaders -DisplayName $roleName

            if ($identities.Count -eq 1) {
                $role = @{
                    "roleName" = $roleAssignment.role.name
                    "userId"   = $identities.Value[0].id
                }
                New-RoleAssignment -OrgName $TargetOrgName -IdentityId $role["userId"] -ProjectId $TargetProjectId `
                    -EndpointId $TargetEndpointId -Role $role -Headers $TargetHeaders
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            else {
                Write-Log -Message "Unable to find role $roleName, please add it manually" -LogLevel WARNING
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

function Get-RoleAssignments([string]$OrgName, [string] $ProjectId, [string] $EndpointId, $Headers) {
    $url = "https://dev.azure.com/$OrgName/_apis/securityroles/scopes/distributedtask.serviceendpointrole/roleassignments/resources/{0}_{1}" -f $ProjectId, $EndpointId

    $results = Invoke-RestMethod -ContentType "application/json" -Method Get -uri $url -Headers $Headers 
    
    return , $results.value
}

function Get-RoleDefinitions {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string]
        $OrgName,
        [Parameter(Mandatory = $TRUE)]
        [string]
        $Headers
    )
    $url = "https://dev.azure.com/$OrgName/_apis/securityroles/scopes/distributedtask.serviceendpointrole/roledefinitions?api-version=7.2-preview.1" 

    $results = Invoke-RestMethod -ContentType "application/json" -Method Get -uri $url -Headers $Headers 
    
    return , $results.value
}

function New-RoleAssignment([string]$OrgName, [string] $IdentityId, [string] $EndpointId, [String] $ProjectId, $Role, $Headers) {
    $url = "https://dev.azure.com/$OrgName/_apis/securityroles/scopes/distributedtask.serviceendpointrole" `
        + "/roleassignments/resources/$($ProjectId)_$($EndpointId)?api-version=5.0-preview.1"

    $body = ConvertTo-Json -Depth 32 @($Role)

    $result = Invoke-RestMethod -ContentType "application/json" -Method Put -uri $url -Headers $Headers -Body $body 
    
    return $result
}

function Remove-AllServiceConnections {
    param (
        [Parameter(Mandatory = $TRUE)]
        [string]
        $OrgName,
        [Parameter(Mandatory = $TRUE)]
        [string]
        $ProjectName,
        [Parameter(Mandatory = $TRUE)]
        [string]
        $ProjectId,
        [Parameter(Mandatory = $TRUE)]
        $Headers        
    )
    
    $endpoints = Get-ServiceEndpoints -OrgName $OrgName `
        -ProjectName $ProjectName -Headers $TargetHeaders

    foreach ($ep in $endpoints) {
        try {
            $url = "https://dev.azure.com/$OrgName/_apis/serviceendpoint" `
                + "/endpoints/$($ep.id)?projectIds=$($ProjectId)" `
                + "&api-version=7.2-preview.4"  
    
            Invoke-RestMethod -Uri $url -Method Delete `
                -Headers $Headers 

            Write-Log "Service Connection $($ep.id) removed."
        }
        catch {
            Write-Log "Unable to remove service endpoint $($ep.id)"
            Write-Log "$($_)"
        }
    }
}
