function Get-Pipelines {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$ProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$OrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $FALSE)]
        [String]$RepoId = $NULL
    )
    if ($PSCmdlet.ShouldProcess($ProjectName)) {

        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/build/definitions?api-version=7.0"
        if ($RepoId) {
            $url = "https://dev.azure.com//$OrgName/$ProjectName/_apis/build/definitions?repositoryId=$RepoId&repositoryType=TfsGit";
        }
    
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers

        return $results.value
    }
}
