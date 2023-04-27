
function Start-ADOVariableGroupsMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $FALSE)] [String]$secretsMapPath = ""
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrgName/$TargetProjectName",
            "Migrate VariableGroups from source project $SourceOrgName/$SourceProjectName")
    ) {

        Write-Log -Message ' '
        Write-Log -Message '----------------------------'
        Write-Log -Message '-- Migrate VariableGroups --'
        Write-Log -Message '----------------------------'
        Write-Log -Message ' '

        $sourceProject = Get-ADOProjects -OrgName $SourceOrgName -ProjectName $sourceProjectName -Headers $sourceHeaders
        $targetProject = Get-ADOProjects -OrgName $TargetOrgName -ProjectName $targetProjectName -Headers $targetHeaders 

        $targetVariableGroups = Get-VariableGroups -projectName $targetProject.name -headers $targetHeaders -orgName $TargetOrgName

        if ($secretsMapPath -ne "") {
            $secretsMap = ((Get-Content -Raw -Path $secretsMapPath) | ConvertFrom-Json) | ConvertTo-HashTable
            Write-Log -Message "Loaded secrets map from $secretsMapPath"    
        }
        else {
            $secretsMap = @{
                serviceHooks = @{
                    webHooks = @{}
                    jenkins  = @{}
                }
            }
            Write-Log -Message "Loaded default secrets map"
        }

        $groups = Get-VariableGroups -projectName $sourceProject.name -orgName $SourceOrgName -headers $sourceHeaders

        foreach ($groupHeader in $groups) {

            if ($null -ne ($targetVariableGroups | Where-Object {$_.name -ieq $groupHeader.name})) {
                Write-Log -Message "Variable group [$($groupHeader.name)] already exists in target.. "
                continue
            }

            Write-Log -Message "Attempting to create [$($groupHeader.name)] in target.. "
            try {

                $groupObj = (Get-VariableGroup -projectName $sourceProject.name -orgName $SourceOrgName -headers $sourceHeaders -groupId $groupHeader.id)
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
                    $ref.description = $groupHeader.description
                    $ref.projectReference.id = $targetProject.id
                    $ref.projectReference.name = $targetProject.name
                }

                $json = @{
                    "description"  = $groupHeader.description
                    "name"         = $group.name
                    "providerData" = $group.providerData
                    "type"         = $group.type
                    "variableGroupProjectReferences" = $groupObj.variableGroupProjectReferences
                    "variables"    = $group.variables
                } | ConvertTo-Json -Depth 32
                
                New-VariableGroup -headers $targetHeaders -projectSk $targetProject.id -orgName $TargetOrgName body $json
                Write-Log -Message "Done!" -LogLevel SUCCESS
            }
            catch {
                Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
                Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
            }
        }
    }
}

