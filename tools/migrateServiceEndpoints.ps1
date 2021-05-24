Param(

    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "-------------------------------"
Write-Log -msg "-- Migrate Service Endpoints --"
Write-Log -msg "-------------------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$endpoints = Get-ServiceEndpoints -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders

$targetEndpoints = Get-ServiceEndpoints -projectSk $TargetProject.id -org $SourceOrg -headers $sourceHeaders

#$endpoints | ConvertTo-Json -Depth 10 | Out-File -FilePath "DEBUG_endpoints.json"

foreach ($endpoint in $endpoints) {

    if ($null -ne ($targetEndpoints | Where-Object {$_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($endpoint.id.ToUpper())")})) {
        Write-Log -msg "Service endpoint [$($endpoint.id)] already exists in target.. "  -NoNewline
        continue
    }

    Write-Log -msg "Attempting to create [$($endpoint.name)] in target.. "  -NoNewline

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
        Write-Log -msg "Done!" -ForegroundColor "Green"
    }
    catch {
        Write-Log -msg "FAILED!" -ForegroundColor "Red"
        Write-Log -msg ($_ | ConvertFrom-Json).message -ForegroundColor "Red"
    }
}
