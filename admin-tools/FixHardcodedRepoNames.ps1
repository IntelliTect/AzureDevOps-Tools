param(
    [string]$sourcePat,
    [string]$sourceOrg, 
    [string]$sourceProjectName, 
    [string]$OutFile, 
    [int]$BatchSize = 50,
    [string]$LogLocation = $PSScriptRoot
)
. .\AzureDevOps-Helpers.ps1 -LogLocation $LogLocation
. .\AzureDevOps-ProjectHelpers.ps1

$final = @()
$sourceHeaders = New-HTTPHeaders -pat $sourcePat
$projectHelpers = "$(Get-Location)\AzureDevOps-ProjectHelpers.ps1"
$helpers = "$(Get-Location)\AzureDevOps-Helpers.ps1"

$projects = (Get-ADOProjects -Headers $sourceHeaders -Org $sourceOrg -ProjectName $sourceProjectName)

$WorkingDir = $PSScriptRoot

Write-Log -msg "Found $($projects.Count) projects.."
Write-Log -msg "Processing projects in batches of $BatchSize.."
    
$jobsBatch = @()
foreach ($project in $projects) {

    if ($jobsBatch.Count -eq $BatchSize) {
        Write-Log -msg "Waiting for current batch to complete.."
            
        Wait-Job -Job $jobsBatch | Out-Null
        foreach ($job in $jobsBatch) {
            $final += Receive-Job -Job $job | ConvertFrom-Json
        }
        Write-Log -msg "Progress ($($final.Count)/$($projects.Count))"
        $jobsBatch = @()
    }
    Write-Log -msg "Collecting info for $($project.name)[$($jobsBatch.Count)] .."

    $jobsBatch += Start-Job -ArgumentList $helpers, $sourceHeaders, $sourceOrg, $project, $projectHelpers -ScriptBlock {
        param ($helpers, $headers, $org, $project, $projectHelpers)
        Import-Module $helpers
        Import-Module $projectHelpers

        try {
            $pipelineFilesToFix = (Get-FilesWithHardcodedRepoNames -projectSk $project.id -projectName $project.Name -org $Org -headers $headers)
            $paths = $pipelineFilesToFix.results.ForEach( { "$($_.repository.name)$($_.path)" })
            $fileNames = $paths -join ", " 
            $repos = $paths | ForEach-Object { "$($_.split("/")[0])" } | select -Unique
            $folder = "$(Get-Location)/../../Temp-Repos"

            if((Test-Path -Path $folder)){
                Get-ChildItem -Path $folder -Recurse | Remove-Item -force -recurse
            } else {
                mkdir $folder
            }
           
            cd $folder
            $bareOrgName = $org.replace("https://dev.azure.com", "")

            foreach($repo in $repos){
                $matchingPaths = $paths | Where-Object { $_.split("/")[0] -eq $repo }
                $url = "https://$bareOrgName@dev.azure.com/$bareOrgName/$($project.Name)/_git/$repo"
                git clone $url
                Push-Location $repo
                forEach ($path in $matchingPaths) {                
                    $formattedPath = "$(Get-Location)$($path.replace($repo, ''))"
                    
                    $text = [IO.File]::ReadAllText($formattedPath)
                    $object = ConvertFrom-Yaml $text
                    forEach ($yamlRepo in $object.resources.repositories){
                        if($yamlRepo.Name.split("/")[0] -eq $project.Name){
                            #Change to GitHub reference
                            $yamlRepo.type = "GitHub"
                            $yamlRepo.ref = "main"
                            $yamlRepo.name = "$GitHubOrg/$GitHubRepoName"
                        }
                    }
                    forEach ($step in $object.steps) {
                        if($step.name -eq "checkout") {
                            #Found custom checkout step
                        }
                    }
                    forEach($stage in $object.stages) {
                        forEach ($step in $stage.steps) {
                            if($step.name -eq "checkout") {
                                #Found custom checkout step
                            }
                        }
                    }
                }
                Pop-Location
            }


            
            return (@{
                   
                    "pipelinesWithHardCodedRepoCount" = $pipelineFilesToFix.count
                    "pipelinesWithHardCodedRepoNames" = $fileNames
                   
                }) | ConvertTo-Json
        }
        catch {
            Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
            Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
            throw
        }
    }
}

Wait-Job -Job $jobsBatch | Out-Null
foreach ($job in $jobsBatch) {
    $final += Receive-Job -Job $job | ConvertFrom-Json
}
    
Write-Log -msg "Done!"

if ($OutFile) {
    $final | Export-CSV $OutFile -NoTypeInformation
}

return $final
