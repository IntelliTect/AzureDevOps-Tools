function Get-Pipelines {
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
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions?api-version=5.1"
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results.value
    }
}
