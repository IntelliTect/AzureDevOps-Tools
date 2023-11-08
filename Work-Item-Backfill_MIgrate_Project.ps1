
Param (
        [Parameter (Mandatory=$FALSE)] [String]$NumberOfDays =  "",
        [Parameter (Mandatory=$FALSE)] [String]$StartDate =  "",
        [Parameter (Mandatory=$FALSE)] [String]$EndDate =  "",
        [Parameter (Mandatory=$FALSE)] [String]$ItemType = "",
        [Parameter (Mandatory=$FALSE)] [Boolean]$WhatIf = $TRUE
)

Write-Host " "
Write-Host "Work-Item back fill migration:"

Write-Host " "
Write-Host "Since the Azure REST API for work items has a query limit if 20,000, calls to the API may require the 'Number of Days Changed' value to be reduced to avoid pulling too many items"
Write-Host " "


Write-Host " "
Write-Host "Migrate Work Items with Changed Date between 0 days Today and 'Number of Days Changed' ago"
Write-Host " "

$queryBit = "AND [System.WorkItemType] NOT IN ('Test Suite','Test Plan','Shared Steps','Shared Parameter','Feedback Request') "

if($NumberOfDays -ne "") {
        $queryBit += "AND [System.ChangedDate] >= @Today - $($NumberOfDays) "
} elseif(($StartDate -ne "" -and $EndDate -ne "") -and ($startDate -ne $endDate)) {
        $queryBit += "AND [System.ChangedDate] >= '$($StartDate)' AND [System.ChangedDate] <= '$($endDate)' "
} elseif($StartDate -ne "") {
        $queryBit += "AND [System.ChangedDate] >= '$($StartDate)' "
}

if($ItemType -ne "") {
        $queryBit += "AND [System.WorkItemType] = '$($ItemType)' "
}

& .\MigrateProject.ps1 -SkipMigrateWorkItems $WhatIf -WorkItemQueryBit $queryBit



