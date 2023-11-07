class ADO_WorkItemType {
    [String]$Id 
    [String]$Name 
    [String]$Description 
    [String]$Url 
    [String]$Inherits 
    [String]$Class 
    [String]$Color 
    [String]$Icon 
    [Bool]$IsDisabled 
    
    ADO_WorkItemType(
        [String]$id,
        [String]$name,
        [String]$description,
        [String]$url,
        [String]$inherits,
        [String]$class,
        [String]$color,
        [String]$icon,
        [Bool]$isDisabled 
    ) {
        $this.Id = $Id 
        $this.Name = $name 
        $this.Description = $description 
        $this.Url = $url 
        $this.Inherits = $inherits 
        $this.Class = $class 
        $this.Color = $color 
        $this.Icon = $icon 
        $this.IsDisabled = $isDisabled 
    }
}

function Start-ADO_AddCustomField {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$Headers,

        [Parameter (Mandatory = $TRUE)] 
        [String]$OrgName, 

        [Parameter (Mandatory = $TRUE)] 
        [String]$PAT,

        [Parameter (Mandatory = $TRUE)] 
        [String]$ProjectName, 

        [Parameter (Mandatory = $TRUE)] 
        [String]$ProcessId,

        [Parameter (Mandatory = $TRUE)] 
        [String]$FieldName,

        [Parameter (Mandatory = $FALSE)] 
        [String]$FieldDefaultValue
    )
    if ($PSCmdlet.ShouldProcess(
            "Project $OrgName/$ProjectName",
            "Add ADO custom Field from source project $OrgName/$ProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '--------------------------------'
        Write-Log -Message '-- Begin Add ADO custom Field --'
        Write-Log -Message '--------------------------------'
        Write-Log -Message ' '

        # See if the custom field exists yet or not. If not it needs to be created before it can be added to any work item type
        $customFields = Get-CustomfieldsList `
            -LocalOrgName $OrgName `
            -LocalProjectName $ProjectName `
            -LocalHeaders $Headers
        
        if($NULL -ne $customFields) {
            if ($null -eq ($customFields | Where-Object { $_.referenceName -ieq $FieldName })) {
                Write-Log -Message "Creating Custom Field `"$FieldName`" for $OrgName/$ProjectName... "
                # Add a new custom field for this org/project so that it can be added to work item types for the process
                New-Customfield `
                    -LocalOrgName $OrgName `
                    -LocalFieldName $FieldName `
                    -LocalHeaders $Headers
            }
        }
        
        # Get the associated work item types for this process by process Id 
        $workitemTypes = Get-ProcessWorkItemTypes `
            -LocalOrgName $OrgName `
            -LocalHeaders $Headers `
            -LocalProcessId $ProcessId

        if ($workitemTypes) {
            foreach ($workitemType in $workitemTypes) {
                # if((!$workitemType.IsDisabled) -and ($workitemType.Class -eq "derived")) {
                if(!$workitemType.IsDisabled) {
                    $workitemType.Id

                    $processDefinitions = Get-ProcessesDefinitions `
                        -LocalOrgName $OrgName `
                        -LocalHeaders $Headers `
                        -LocalProcessId $ProcessId `
                        -LocalWorkItemType $workitemType

                    if($NULL -ne $processDefinitions) {
                        if ($null -ne ($processDefinitions | Where-Object { $_.referenceName -ieq $FieldName })) {
                            Write-Log -Message "Custom Field `"$FieldName`" already exists for $OrgName/$ProjectName Work Item Type [$($workitemType.Id)]... "
                            continue
                        }

                        Write-Log -Message "ADDing Custom Field `"$FieldName`" for $OrgName/$ProjectName Work Item Type [$($workitemType.Id)]... "
                        Add-CustomField `
                            -LocalOrgName $OrgName `
                            -LocalHeaders $Headers `
                            -LocalProcessId $ProcessId `
                            -LocalWorkItemType $workitemType `
                            -LocalFieldName $FieldName
                    }
                }
            }
        }

    }
}


function Get-ProcessWorkItemTypes {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$LocalProcessId
    )
    $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processes/$LocalProcessId/workitemtypes?api-version=7.0"

    $results = Invoke-RestMethod -Method GET -Uri $url -Headers $LocalHeaders

    [ADO_WorkItemType[]]$workItemTypes = @()
    foreach ($result in $results.Value) {
        $workItemTypes += (ConvertTo-WorkItemTypeObject -WorkItemType $result)
    }
    return $workItemTypes
}

function Add-CustomField {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$LocalProcessId,

        [Parameter (Mandatory = $TRUE)]
        [ADO_WorkItemType]$LocalWorkItemType,

        [Parameter (Mandatory = $TRUE)] 
        [String]$LocalFieldName
    )
    if ($PSCmdlet.ShouldProcess($WorkItemType.Name)) {
        # $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processes/$LocalProcessId/workItemTypes/$($LocalWorkItemType.Id)/fields?api-version=7.0"
        $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processdefinitions/$LocalProcessId/workItemTypes/$($LocalWorkItemType.Id)/fields?api-version=7.0"

        $body = @"
{
    "defaultValue": "",
    "referenceName": "$LocalFieldName",
    "name": "Custom Work Item Field - ReflectedWorkItemId",
    "type": "plainText",
    "readOnly": false,
    "required": false,
    "pickList": null,
    "url": null,
    "allowGroups": null
}
"@
        Invoke-RestMethod -Method POST -Uri $url -Body $body -Headers $headers -ContentType "application/json"
    }
}

function ConvertTo-WorkItemTypeObject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)]
        [Object]$WorkItemType
    )
    if ($PSCmdlet.ShouldProcess($WorkItemType.Name)) {
        [ADO_WorkItemType]$ADOWorkItemType = [ADO_WorkItemType]::new(
            $WorkItemType.Id,
            $WorkItemType.Name, 
            $WorkItemType.Description,
            $WorkItemType.Url,
            $WorkItemType.Inherits, 
            $WorkItemType.Class, 
            $WorkItemType.Color, 
            $WorkItemType.Icon,
            $WorkItemType.IsDisabled 
        )

        return $ADOWorkItemType
    }
}

function Get-Processes {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders
    )
    $url = "https://dev.azure.com/$LocalOrgName/_apis/process/processes?api-version=7.0"

    $results = Invoke-RestMethod -Method GET -Uri $url -Headers $LocalHeaders

    return $results.value
}

function Get-ProcessesDefinitions {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$LocalProcessId,

        [Parameter (Mandatory = $TRUE)]
        [ADO_WorkItemType]$LocalWorkItemType
    )
    $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processes/$LocalProcessId/workItemTypes/$($LocalWorkItemType.Id)/fields?api-version=7.0"

    $results = Invoke-RestMethod -Method GET -Uri $url -Headers $LocalHeaders

    return $results.value
}

function Get-CustomfieldsList {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)] 
        [String]$LocalProjectName, 

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders
    )
    $url = "https://dev.azure.com/$OrgName/$LocalProjectName/_apis/wit/fields?api-version=7.0"

    $results = Invoke-RestMethod -Method GET -Uri $url -Headers $LocalHeaders

    return $results.value
}

function New-Customfield {
    param(
        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders,

        [Parameter (Mandatory = $TRUE)] 
        [String]$LocalFieldName
    )
    $url = "https://dev.azure.com/$LocalOrgName/$ProjectName/_apis/wit/fields?api-version=7.0"

    $body = @"
{
    "name": "Custom Work Item Field - ReflectedWorkItemId",
    "referenceName": "$LocalFieldName",
    "description": "Custom field used by data migration tool.",
    "type": "string",
    "usage": "workItem",
    "readOnly": false,
    "canSortBy": true,
    "isQueryable": true,
    "supportedOperations": [
        {
        "referenceName": "SupportedOperations.Equals",
        "name": "="
        }
    ],
    "isIdentity": true,
    "isPicklist": false,
    "isPicklistSuggested": false,
    "url": null
}
"@
    $results = Invoke-RestMethod -Method POST -Uri $url -Body $body -Headers $LocalHeaders -ContentType "application/json"

    return $results
}

