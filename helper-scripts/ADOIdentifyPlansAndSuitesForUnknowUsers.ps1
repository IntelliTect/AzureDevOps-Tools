
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$TRUE)] [String]$OutputFile
)


Write-Host "Begin - Identify Plans/Suites/Test-Cases whos owner is not a user identity in the organization"
Write-Host "Source Organization - $OrgName"
Write-Host " "

Start-Transcript -Path $OutputFile -Append

 Write-Host "Get Organization User Identities.."
 Set-AzDevOpsContext -PersonalAccessToken $PAT -OrgName $OrgName

 Write-Host "Calling az devops user list.." -NoNewline
 $results = az devops user list --detect $False | ConvertFrom-Json

 $members = $results.members
 $totalCount = $results.totalCount
 $counter = $members.Count
 do {
     $UserResponse = az devops user list --detect $False --skip $counter | ConvertFrom-Json
     Write-Host ".." -NoNewline
     $members += $UserResponse.members
     $counter += $UserResponse.members.Count
 } while ($counter -lt $totalCount)
 Write-Host " "

$orgUsers = @()
 foreach ($orgUser in $members ) {
     $orgUsers += $orgUser
 }

$orgUserNames = (($orgUsers | Select-Object -ExpandProperty User) | Select-Object -ExpandPropert principalName).ToLower()
$orgUserNames = $orgUserNames | Sort-Object

 Write-Host "Get Plans/Suites/Test-Cases and validate that the owner is in the Organization list"

# Create Headers
$Headers = New-HTTPHeaders -PersonalAccessToken $PAT


# Get all fields for the source organization
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/test/plans?api-version=5.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
$sourcePlans = $results.Value

$tpsOwners = @()
$tpsWithBadOwner = @()
foreach ($plan in $sourcePlans) {
        Write-Host "Plan Name: $($plan.name)"

        # Get all suites for the source Plan
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
        $sourceSuites = $results.Value

        foreach ($suite in $sourceSuites) {
                Write-Host "     Suite Name: $($suite.name)"

                 # Get all Test-Cases for the source Suite
                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/test/Plans/$($plan.id)/suites/$($suite.id)/testcases?api-version=7.0"
                $results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
                $sourceTestCases = $results.Value

                foreach ($testcase in $sourceTestCases) {
                        Write-Host "             Test-Case Name: $($testcase.name)"
                        foreach ($assignment in $testcase.pointAssignments) {
                                $tpsUser = $assignment.tester.uniqueName
                                Write-Host "                     User Name: $tpsUser"
                                $tpsOwners += $tpsUser

                                # Check if owner is in known list
                                $userCheck = $orgUserNames | Where-Object { $_ -eq $tpsUser }
                                if ($NULL -eq $userCheck) {
                                        Write-Host "                            Bad User Identity Assigned!"
                                        $tpsWithBadOwner += "Plan Name: $($plan.name) :: Suite Name: $($suite.name) :: Test-Case Name: $($testcase.name) :: User Name: $tpsUser"
                                }
                        }
                }
        }
}



# Compare the two collections - $users and $tpsOwners
$tpsOwners = $tpsOwners | Select-Object -Unique
$tpsOwners = $tpsOwners | Sort-Object
$diffUserNames = $tpsOwners | Where-Object { $_ -notin $orgUserNames }

Write-Host "Diff Users: $($diffUserNames.Count)"
foreach ($orgUserName in $diffUserNames) {
        Write-Host "$orgUserName "   
}
Write-Host " "
Write-Host " "
Write-Host "Bad Plan/Suite/Test-Case User Identities: $($tpsWithBadOwner.Count)"
foreach ($tpsBadUserName in $tpsWithBadOwner) {
        Write-Host "$tpsBadUserName "   
}
Write-Host " "
Write-Host " "
Write-Host "End - Identify Plans/Suites/Test-Cases whos owner is not a user identity in the organization"

Stop-Transcript


