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

        $workitemTypes = Get-ProcessWorkItemTypes `
            -LocalProjectName $ProjectName `
            -LocalOrgName $OrgName `
            -LocalHeaders $Headers `
            -LocalProcessId $ProcessId

        if ($workitemTypes) {
            foreach ($workitemType in $workitemTypes) {
                # if((!$workitemType.IsDisabled) -and ($workitemType.Class -eq "derived"))
                if (!$workitemType.IsDisabled) {
                    $workitemType.Id
                    Add-CustomField `
                        -LocalProjectName $ProjectName `
                        -LocalOrgName $OrgName `
                        -LocalHeaders $Headers `
                        -LocalProcessId $ProcessId `
                        -WorkItemType $workitemType
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
    $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processes/$LocalProcessId/workitemtypes?api-version=4.1-preview.1"

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
        [String]$LocalProjectName,

        [Parameter (Mandatory = $TRUE)]
        [String]$LocalOrgName,

        [Parameter (Mandatory = $TRUE)]
        [Hashtable]$LocalHeaders,

        [Parameter (Mandatory = $TRUE)]
        [String]$LocalProcessId,

        [Parameter (Mandatory = $TRUE)]
        [ADO_WorkItemType]$WorkItemType
    )
    if ($PSCmdlet.ShouldProcess($WorkItemType.Name)) {
        # TODO: Write logic here

        $url = "https://dev.azure.com/$LocalOrgName/_apis/work/processdefinitions/$LocalProcessId/workItemTypes/$($WorkItemType.Id)/fields?api-version=4.1-preview.1"

        $body = @"
{
    "defaultValue": "",
    "referenceName": "Custom.ReflectedWorkItemId",
    "name": null,
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