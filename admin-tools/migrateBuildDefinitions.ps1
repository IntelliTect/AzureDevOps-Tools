# TODO: TFVC based projects require some manual fix-up when it comes to mapping repository pathing

Param(
    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName,
    [bool]$withHistory = $true,

    [string]$secretsMapPath = ""
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "------------------------"
Write-Log -msg "-- Migrate Build Defs --"
Write-Log -msg "------------------------"
Write-Log -msg " "

function MigrateDefinition($def) {

    #$body | Out-File -FilePath "builddef-$($buildDefinition.name).json"

    $def.project.id = $targetProject.id
    $def.project.url = $targetProject.url
    $def.project.description = $def.project.description -replace ":", ""

    $def.queue = ($targetBuildQueues | Where-Object { $_.name -eq $def.queue.name })

    if ($null -ne $def.repository -and $def.repository.id.Contains("http")) {
        # It looks like it may be a repo based on a service endpoint.. lets try and map it up
        Write-Log -msg "Mapping Repo via service endpoint .."
        $sourceEndpoint = Get-ServiceEndpoint -headers $sourceHeaders -org $sourceOrg -serviceEndpointId $def.repository.properties.connectedServiceId -projectSk $sourceProject.id
        $targetEndpoint = ($targetServiceEndpoints | Where-Object { $_.description.ToUpper().Contains("#ORIGINSERVICEENDPOINTID:$($sourceEndpoint.id.ToUpper())") })
        if ($null -ne $targetEndpoint) {
            $def.repository.properties.connectedServiceId = $targetEndpoint.id
        }
        else {
            throw "Failed to locate service endpoint repository [$($sourceRepo.name)] in target. "
        }
    }
    elseif ($null -ne $def.repository ) {
        if ("TfsVersionControl" -eq $def.repository.type) {
            Write-Log -msg "Mapping TFVC Repo.."
            $def.repository.name = $targetProject.name
            $def.repository.url = $targetOrg
            $def.repository.defaultBranch = $def.repository.defaultBranch -replace $sourceProject.name, "$($targetProject.name)/$($sourceProject.name)"
            $def.repository.rootFolder = $def.repository.rootFolder -replace $sourceProject.name, "$($targetProject.name)/$($sourceProject.name)"
        }
        else {
            Write-Log -msg "Mapping Git Repo.."
            Write-Host ($def.repository | ConvertTo-Json -Depth 10)
            $sourceRepo = Get-Repo -headers $sourceHeaders -org $sourceOrg -repoId $def.repository.id
            $targetRepo = ($targetRepos | Where-Object { $_.name -ieq $sourceRepo.name })
            if ($null -ne $targetRepo) {
                $def.repository.id = $targetRepo.id
                $def.repository.url = $targetRepo.url
            }
            else {
                throw "Failed to locate repository [$($sourceRepo.name)] in target. "
            }
        }
    }
    Write-Log -msg "Matching Variable Groups.."
    if ($null -ne $def.variableGroups) {
        foreach ($varGroup in $def.variableGroups) {
            $targetVG = $targetVariableGroups | Where-Object { $_.name -ieq $varGroup.name }
            if ($null -ne $targetVG) {
                $varGroup.id = $targetVG.id
            }
            else {
                throw "Failed to locate variable group [$($varGroup.name)] in target. "
            }
        }
    }

    Write-Log -msg "Mapping Variables.."
    if ($null -ne $def.variables) {
        foreach ($var in $def.variables.psobject.properties) {
            if ($true -eq $var.Value.isSecret) {
                if ($null -ne $secretsMap.buildDefinitions -and
                    $null -ne $secretsMap.buildDefinitions[$def.name] -and
                    $null -ne $secretsMap.buildDefinitions[$def.name][$var.Name]) {
                    $var.Value.value = $secretsMap.buildDefinitions[$def.name][$var.Name]
                }
                else {
                    throw "Secrets mapping for BuildDefinition - $($def.name) is missing or doesn`'t contain required [$($var.Name)] field."
                }
            }
        }
    }
    return Save-BuildDefinition -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -revision $def.revision -buildDefinition $def
}

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $SourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$buildDefinitions = Get-BuildDefinitions -projectSk $SourceProject.id -org $SourceOrg -headers $sourceHeaders
$targetBuildDefinitions = Get-BuildDefinitions -projectSk $TargetProject.id -org $TargetOrg -headers $targetHeaders

if ($secretsMapPath -ne "") {
    $secretsMap = ((Get-Content -Raw -Path $secretsMapPath) | ConvertFrom-Json) | ConvertTo-HashTable
    Write-Log -msg "Loaded secrets map from $secretsMapPath"    
}
else {
    $secretsMap = @{
        serviceHooks = @{
            webHooks = @{}
            jenkins  = @{}
        }
    }
    Write-Log -msg "Loaded default secrets map"
}

$targetRepos = Get-Repos -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg
$targetVariableGroups = Get-VariableGroups -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg
$targetBuildQueues = Get-BuildQueues -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg
$targetServiceEndpoints = Get-ServiceEndpoints -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg

Write-Log -msg "Located $($buildDefinitions.Count) build defs in source."

foreach ($buildDefinition in $buildDefinitions) {

    if ($null -ne ($targetBuildDefinitions | Where-Object {$_.name -ieq $buildDefinition.name})) {
        Write-Log -msg "Build definition [$($buildDefinition.name)] already exists in target.. "  -NoNewline
        continue
    }

    Write-Log -msg "Attempting to create $($buildDefinition.name) in target.. "

    try {
        if ($true -eq $withHistory) {
            Write-Log -msg "Found $($buildDefinition.revision) revisions for $($buildDefinition.name)."
            $newId = 0
            $newUrl = ""
            for ($rev = 1; $rev -le $buildDefinition.revision; $rev++) {
                $def = Get-BuildDefinition -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders -buildDefinitionId $buildDefinition.id -revision $rev   
                if ($rev -gt 1) {
                    $def.id = $newId
                    $def.url = $newUrl
                    $def.uri = "vstfs:///Build/Definition/$($newId)"
                }
                Write-Log -msg "Migrating revision $rev for $($def.name).. "
                $saved = MigrateDefinition($def)
                if ($rev -eq 1) {
                    $newId = $saved.id
                    $newUrl = $saved.url
                }
            }
        }
        else {
            $def = Get-BuildDefinition -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders -buildDefinitionId $buildDefinition.id
            Write-Log -msg "Migrating $($def.name).. "
            $def.revision = 1
            $saved = MigrateDefinition($def)
        }
        Write-Log "Done migrating $($buildDefinition.name)." -ForegroundColor "Green"
    }
    catch {
        Write-Log -msg ($_.Exception | Format-List -Force | Out-String) -logLevel "ERROR"
        Write-Log -msg ($_.InvocationInfo | Format-List -Force | Out-String) -logLevel "ERROR"
        throw
    }
}
Write-Log "Done migrating build definitions." -ForegroundColor "Green"