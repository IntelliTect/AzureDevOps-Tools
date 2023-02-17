# https://docs.microsoft.com/en-us/rest/api/azure/devops/memberentitlementmanagement/user%20entitlements/add?view=azure-devops-rest-5.1

function Add-ADOUser([string]$pat, [string]$orgName, [string]$user, [string]$licenseType = "stakeholder") {
    $url = "https://vsaex.dev.azure.com/$orgName/_apis/userentitlements?api-version=5.1-preview.1"

    $body = @{
        "accessLevel" = @{
            "accountLicenseType" = $licenseType
        }
        "user" = @{
            "principalName" = $user
            "subjectKind" = "user"
        }
    } | ConvertTo-Json -Depth 3

    try {
        $result = Invoke-RestMethod -Uri $url -Method "Post" -Headers (New-HTTPHeaders -pat $pat) -Body $body - UseBasicParsing -ContentType 'application/json'
    }
    catch {
        Write-Error "Error adding user $user to org $org : $_"
    }
    return $result
}

function get-ADOUsers($pat, [string]$OrgName) {
    #todo OAuth token: https://docs.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops
    $url = "https://vssps.dev.azure.com/$orgName/_apis/graph/users?api-version=5.1-preview.1"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    return $results
}

function Get-ADOUserEntitlements($pat, [string]$OrgName)  {
    #todo Service apis 
    # GET https://vsaex.dev.azure.com/{organization}/_apis/userentitlementsummary?api-version=5.1-preview.1
    $url = "https://vsaex.dev.azure.com/$orgName/_apis/userentitlementsummary?api-version=5.1-preview.1"
    $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    return $results
}


function Get-ADOSecurityNamespaes($pat, [string]$org, [string]$namespace) {
    if ($namespace) {
        $url = "$org/_apis/securitynamespaces/$namespace?api-version=5.1"
    }
    else {
        $url = "$org/_apis/securitynamespaces?api-version=5.1"
    }

    $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    if ($ProcessName) {
        return $results.value | Where-Object {$_.name -ieq $ProcessName}
    }
    else {
        return $results.value
    }
}

function Get-ADOAccessControlList([string]$namespaceId, [string]$org, [string]$pat) {
    # POST https://dev.azure.com/{organization}/_apis/accesscontrollists/{securityNamespaceId}?api-version=5.1
    $url = "$org/_apis/accesscontrollists/"+$namespaceId+"?api-version=5.0"

    try {
        $results = Invoke-RestMethod -Method Get -uri $url -Headers (New-HTTPHeaders -pat $pat)
    }
    catch {
        Write-Error "Error getting ACL for $namespaceId : $_"
    }
    return $results
}

