
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$FALSE)] [Switch]$GenerateAverages,
        [Parameter (Mandatory=$TRUE)] [String]$OutputFile
)

Write-Host "Begin Generate Artifact Feed Package Version Data found in ($OrgName/$ProjectName)... "
Write-Host " "

 # Create Headers
$headers = New-HTTPHeaders -PersonalAccessToken $PAT

Start-Transcript -Path $OutputFile -Append

$url = "https://feeds.dev.azure.com/$OrgName/$ProjectName/_apis/packaging/feeds?api-version=7.0"
$results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
$feeds = $results.Value

Write-Host "This process is time consuming and will take a while, be patient..."

foreach($feed in $feeds) {
        $url = $feed._links.Packages.href
        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
        $packages = $results.Value

        if($GenerateAverages -eq $TRUE) {
                $versionCount = 0
                foreach($package in $packages) {
                        $url = $package._links.versions.href
                        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
                        $versions = $results.Value
                        $versionCount += $versions.Count
                }
                
                $versionAvgCount = 0
                if($versionCount -gt 0){
                        $versionAvgCount = [math]::ceiling($versionCount / $packages.Count)
                }

                Write-Log -Message "Feed $($feed.Name) : $($packages.Count) Packages : $($versionAvgCount) Average Version Count"

        } else {
                Write-Log -Message "Feed $($feed.Name) : $($packages.Count) Packages"
                foreach($package in $packages) {
                        $url = $package._links.versions.href
                        $results = Invoke-RestMethod -Method Get -uri $url -Headers $headers
                        $versions = $results.Value
                        Write-Log -Message "        - Package: $($package.Name) : $($versions.Count) Versions"
                }
        }

}
Write-Log ' '
Stop-Transcript

Write-Host "End Generate Artifact Feed Package Version Data... "


