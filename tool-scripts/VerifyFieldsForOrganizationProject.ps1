
Param (
        [Parameter (Mandatory=$TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$SourcePAT,

        [Parameter (Mandatory=$TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$TargetPAT
)

Write-Host "Begin Validate ADO custom Fields for the Processes"

 # Create Headers
 $sourceHeaders = New-HTTPHeaders -PersonalAccessToken $SourcePAT
 $targetHeaders = New-HTTPHeaders -PersonalAccessToken $TargetPAT

 
Write-Host "Begin Validate ADO custom Fields for the Processes"
Write-Host "Source - $SourceOrgName/$SourceProjectName"
Write-Host "Target - $TargetOrgName/$TargetProjectName"
Write-Host " "


if(($SourceProjectName -ne "") -and ($TargetProjectName -ne "")) {
        Write-Host " "
        Write-Host "Begin Validate ADO custom Fields for the Source and Target Projects"
        Write-Host "Source Process Id - $SourceProjectName"
        Write-Host "Target Process Id - $TargetProjectName"
        Write-Host " "

        # Get all fields for the Source process/project
        $url = "https://dev.azure.com/$SourceOrgName/$SourceProjectName/_apis/wit/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $sourceHeaders
        $sourceProcessFields = $results.Value

        # Get all fields for the Target process/project
        $url = "https://dev.azure.com/$TargetOrgName/$TargetProjectName/_apis/wit/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $targetHeaders
        $targetProcessFields = $results.Value


        $writeHeader = $TRUE
        foreach ($field in $sourceProcessFields) {
                if ($null -ne ($targetProcessFields | Where-Object { $_.referenceName -ieq $field.referenceName })) {  continue  }

                if($writeHeader) {
                        Write-Log -Message "Work Item Fields that exists in Source project ($SourceOrgName/$SourceProjectName) but not in Target project($TargetOrgName/$TargetProjectName)... "
                        $writeHeader = $FALSE
                }
                Write-Log $field.referenceName
        }
} else {
        # Get all fields for the Source organization
        $url = "https://dev.azure.com/$SourceOrgName/_apis/wit/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $sourceHeaders
        $sourceProcessFields = $results.Value

        # Get all fields for the Target organization
        $url = "https://dev.azure.com/$TargetOrgName/_apis/wit/fields?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $targetHeaders
        $targetProcessFields = $results.Value


        $writeHeader = $TRUE
        foreach ($field in $sourceProcessFields) {
                if ($null -ne ($targetProcessFields | Where-Object { $_.referenceName -ieq $field.referenceName })) {  continue  }

                if($writeHeader) {
                        Write-Log -Message "Work Item Fields that exists in Source Process but not in Target Process... "
                        $writeHeader = $FALSE
                }
                Write-Log $field.referenceName
        }
}

Write-Host "End Validate ADO custom Fields "


