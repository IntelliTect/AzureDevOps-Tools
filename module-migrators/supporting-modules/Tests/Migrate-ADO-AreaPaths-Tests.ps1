BeforeAll {
    Import-Module .\supporting-modules\Migrate-ADO-AreaPaths.psm1 -Force

    Import-Module .\supporting-modules\Tests\Get-Test-Context.psm1 -Force
    $TestContext = Get-TestContext `
        -SourceOrgName "Micron-Testing" `
        -SourceProjectName "SourceTests" `
        -TargetOrgName "Micron-Testing" `
        -TargetProjectName "TargetTests"
}

Describe 'Get-AreaPaths' {
    it 'Should get Area Paths for the given project' {
        $areaPaths = Get-AreaPaths `
            -ProjectName $TestContext.SourceProjectName `
            -OrgName $TestContext.SourceOrgName `
            -Headers $TestContext.SourceHeaders

        $areaPaths | Should -Not -Be $null
    }
}