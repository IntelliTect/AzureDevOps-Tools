Param(

    [string]$TargetOrg = $targetOrg,
    [string]$TargetProjectName = $targetProjectName,
    [string]$TargetPat = $targetPat,

    [string]$SourcePat = $sourcePat,
    [string]$SourceOrg = $sourceOrg,
    [string]$SourceProjectName = $sourceProjectName,

    [string]$secretsMapPath = ""
)

. .\AzureDevOps-Helpers.ps1
. .\AzureDevOps-ProjectHelpers.ps1

Write-Log -msg " "
Write-Log -msg "-----------------------------"
Write-Log -msg "-- Migrate Variable Groups --"
Write-Log -msg "-----------------------------"
Write-Log -msg " "

$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$targetHeaders = New-HTTPHeaders -pat $targetPat

$sourceProject = Get-ADOProjects -org $sourceOrg -Headers $sourceHeaders -ProjectName $sourceProjectName
$targetProject = Get-ADOProjects -org $targetOrg -Headers $targetHeaders -ProjectName $targetProjectName

$targetVariableGroups = Get-VariableGroups -projectSk $targetProject.id -headers $targetHeaders -org $targetOrg

$maskedValue = "********"

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

$groups = Get-VariableGroups -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders

foreach ($groupHeader in $groups) {

    if ($null -ne ($targetVariableGroups | Where-Object {$_.name -ieq $groupHeader.name})) {
        Write-Log -msg "Variable group [$($groupHeader.name)] already exists in target.. "  -NoNewline
        continue
    }

    Write-Log -msg "Attempting to create [$($groupHeader.name)] in target.. "  -NoNewline
    try {

        $groupObj = (Get-VariableGroup -projectSk $sourceProject.id -org $SourceOrg -headers $sourceHeaders -groupId $groupHeader.id)
        $group = $groupObj | ConvertTo-Hashtable

        if ($null -ne $secretsMap.variableGroups -and $null -ne $secretsMap.variableGroups[$group.name]) {
            foreach ($key in $secretsMap.variableGroups[$group.name].Keys) {
                if ($null -ne $group.variables[$key]) {
                    $group.variables[$key].value = $secretsMap.variableGroups[$group.name][$key]
                }
            }
        }

        foreach ($key in $group.variables.Keys) {
            if ($null -eq $group.variables[$key].value) {
                throw "Missing secrets mapped variable '$($varProp.Name)' in variable group '$($group.name)'"
            }
        }

        foreach ($ref in $groupObj.variableGroupProjectReferences) {
            $ref.name = $group.name
            #$ref.description = $groupHeader.description
            $ref.projectReference.id = $targetProject.id
            $ref.projectReference.name = $targetProject.name
        }

        New-VariableGroup -headers $targetHeaders -projectSk $targetProject.id -org $targetOrg -group @{
            #"description"  = $groupHeader.description
            "name"         = $group.name
            "type"         = $group.type
            "providerData" = $group.providerData
            "variables"    = $group.variables
            "variableGroupProjectReferences" = $groupObj.variableGroupProjectReferences
        }
        Write-Log -msg "Done!" -ForegroundColor "Green"
    }
    catch {
        Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
        Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
    }
}