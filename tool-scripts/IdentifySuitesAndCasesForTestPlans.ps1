
Param (
        [Parameter (Mandatory=$TRUE)] [String]$OrgName, 
        [Parameter (Mandatory=$TRUE)] [String]$ProjectName, 
        [Parameter (Mandatory=$TRUE)] [String]$PAT,
        [Parameter (Mandatory=$TRUE)] [String]$OutputFile
)


Write-Host "Begin - Identify Test Suites/Test-Cases for each Test-Plan in the organization"
Write-Host "Source Organization - $OrgName"
Write-Host " "

Start-Transcript -Path $OutputFile -Append

# Create Headers
$Headers = New-HTTPHeaders -PersonalAccessToken $PAT


# Get all fields for the source organization
$url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/test/plans?api-version=5.0"
$results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
$sourcePlans = $results.Value

foreach ($plan in $sourcePlans) {
        Write-Host "Plan (id) Name: ($($plan.id)) $($plan.name)"

        # Get all suites for the source Plan
        $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.0"
        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
        $sourceSuites = $results.Value

        Write-Host "    Suite Count: $($sourceSuites.Count)"
        foreach ($suite in $sourceSuites) {
                Write-Host "    Suite (id) Name: ($($suite.id)) $($suite.name)"
                if($NULL -ne $suite.parentSuite) {
                        Write-Host "    Parent Suite: ($($suite.parentSuite.id)) $($suite.parentSuite.name)"
                }

                # Get all Test-Cases for the source Suite
                $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/test/Plans/$($plan.id)/suites/$($suite.id)/testcases?api-version=7.0"
                $results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers
                $sourceTestCases = $results.Value

                Write-Host "        Test-Case Count: $($sourceTestCases.Count)" 
                foreach ($testcase in $sourceTestCases) {

                        # Get Test-Case details for the source Suite
                        $url = $testcase.testCase.Url
                        $results = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers

                        Write-Host "        Test-Case (id) Name: ($($results.id)) $($results.fields."System.Title")"
                }
        }
}

Write-Host " "
Write-Host " "
Write-Host "End - Identify Test Suites/Test-Cases for each Test-Plan in the organization"

Stop-Transcript


