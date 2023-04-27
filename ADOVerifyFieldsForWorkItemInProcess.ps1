
Param (
        [Parameter (Mandatory=$FALSE)] [String]$SourceProjectName = "", 
        [Parameter (Mandatory=$FALSE)] [String]$SourceOrgName = "", 
        [Parameter (Mandatory=$FALSE)] [String]$SourcePAT = "",
        [Parameter (Mandatory=$FALSE)] [String]$SourceProcessId = "",

        [Parameter (Mandatory=$FALSE)] [String]$TargetProjectName = "", 
        [Parameter (Mandatory=$FALSE)] [String]$TargetOrgName = "", 
        [Parameter (Mandatory=$FALSE)] [String]$TargetPAT = "",
        [Parameter (Mandatory=$FALSE)] [String]$TargetProcessId = ""
)

Write-Host "Begin Validate ADO custom Fields for the Processes"

 # Create Headers
 $sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
 $targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

 
Write-Host "Begin Validate ADO custom Fields for the Processes"
Write-Host "Source - $SourceProcessId"
Write-Host "Target - $TargetProcessId"
Write-Host " "


# Get Source work item types
$url = "https://dev.azure.com/$SourceOrgName/_apis/work/processdefinitions/$SourceProcessId/workitemtypes?api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $sourceHeaders
$sourceWorkItemTypes = $results.Value

# Get Target work item types
$url = "https://dev.azure.com/$TargetOrgName/_apis/work/processdefinitions/$TargetProcessId/workitemtypes?api-version=7.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $sourceHeaders
$targetWorkItemTypes = $results.Value


$sourceWorkItemFields = New-Object Collections.Generic.List[string]
foreach($sourceWorkItemType in $sourceWorkItemTypes){
        # Get all fields for the the work item type
        $url = "https://dev.azure.com/$SourceOrgName/_apis/work/processes/$SourceProcessId/workItemTypes/$($sourceWorkItemType.id)/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $sourceHeaders
        
        foreach($sourcefield in $results.Value){
                $sourceWorkItemFields.Add($sourcefield.referenceName)    
        }
}


$targetWorkItemFields = New-Object Collections.Generic.List[string]
foreach($targetWorkItemType in $targetWorkItemTypes){
        # Get all fields for the the work item type
        $url = "https://dev.azure.com/$TargetOrgName/_apis/work/processes/$TargetProcessId/workItemTypes/$($targetWorkItemType.id)/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $targetHeaders
        
        foreach($targetfield in $results.Value){
                $targetWorkItemFields.Add($targetfield.referenceName)    
        }
}

$writeHeader = $TRUE
foreach ($field in $sourceWorkItemFields) {
        if ($targetWorkItemFields -like $field) {  continue  }

        if($writeHeader) {
                Write-Log -Message "Work Item Fields that exists in Source Process but not in Target Process... "
                $writeHeader = $FALSE
        }
        Write-Log $field
}

Write-Host "End Validate ADO custom Fields "


