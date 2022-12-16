# --- WITAdmin Wrapper Functions ---
# Currently implemented: exportwitd, importwitd, renamewitd, changefield, importlinktype, importprocessconfig

<#
.SYNOPSIS
    Executes WitAdmin.exe with the supplied parameters.
.PARAMETER Arguments
    URL of the target TFS server
#>

function Invoke-TFSWITAdmin
{
    param 
    ( 
        [string] $Arguments 
    )

    $WITAdminPath = 'C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\WitAdmin.exe'

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo

    $pinfo.FileName = $WITAdminPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Arguments

    Write-Verbose ('Executing shell command: WitAdmin.exe {0}' -f $Arguments)

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    Write-Debug "stdout: $stdout"
    Write-Debug "stderr: $stderr"

    $executionResultObject = New-Object PSObject -Property @{ 
        StandardOutput         = $stdout  
        StandardErrorOutput    = $stderr
        ExitCode               = $p.ExitCode
    }

    Write-Output $executionResultObject

}

<#
.SYNOPSIS
    Wrapper for the WITAdmin exportwitd command
#>
function Invoke-TFSWITAdmin_ExportWITD
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipeline=$true)][string] $Project,
        [string] $TypeName,
        [string] $FileName,
        [string] $Encoding,
        [switch] $ExportGlobalLists      
    )  
            
    process
    {
        $Arguments = 'exportwitd /collection:"{0}" /p:"{1}" /n:"{2}" /f:"{3}"' -f $TFSProjectCollectionUrl, $Project, $TypeName, $FileName
        if ($Encoding) { $Arguments = $Arguments + (' /e:"{0}"' -f $Encoding) }
        if ($ExportGlobalLists.IsPresent) { $Arguments = $Arguments + ' /exportgloballists'}
            
        $result = Invoke-TFSWITAdmin -Arguments $Arguments 

        $actionLogObject = New-Object PSObject -Property @{ 
            ExitCode            = $result.ExitCode
            Project             = $Project
            FileName            = $FileName
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {
            $actionLogObject.ActionText = 'Sucessfully exported work item "{0}" into file "{1}".' -f $TypeName, $FileName
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error exporting work item "{0}" into file "{1}".' -f $TypeName, $FileName
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
             
}


<#
.SYNOPSIS
    Wrapper for the WITAdmin importwitd command
#>
function Invoke-TFSWITAdmin_ImportWITD
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipeline=$true)][string] $Project,
        [string] $FileName,
        [string] $Encoding,
        [switch] $Verify
    )  
            
    process
    {
        $Arguments = 'importwitd /collection:"{0}" /p:"{1}" /f:"{2}"' -f $TFSProjectCollectionUrl, $Project, $FileName
        if ($Encoding) { $Arguments = $Arguments + (' /e:"{0}"' -f $Encoding) }  
        if ($Verify.IsPresent) { $Arguments = $Arguments + ' /v'}
             
        $result = Invoke-TFSWITAdmin -Arguments $Arguments
               
        $actionLogObject = New-Object PSObject -Property @{ 
            ExitCode            = $result.ExitCode
            Project             = $Project
            FileName            = $FileName
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {
            $actionLogObject.ActionText = 'Sucessfully imported work item file "{0}" into project "{1}."' -f $FileName, $Project
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error importing work item file "{0}" into project "{1}."' -f $FileName, $Project
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
             
}


<#
.SYNOPSIS
    Wrapper for the WITAdmin renamewitd command
#>
function Invoke-TFSWITAdmin_RenameWITD
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipeline=$true)][string] $Project,
        [string] $CurrentTypeName,
        [string] $NewTypeName
    )  
            
    process
    {
        $Arguments = 'renamewitd /collection:"{0}" /p:"{1}" /n:"{2}" /new:"{3}" /noprompt' -f $TFSProjectCollectionUrl, $Project, $CurrentTypeName, $NewTypeName
               
        $result = Invoke-TFSWITAdmin -Arguments $Arguments 

        $actionLogObject = New-Object PSObject -Property @{ 
            CurrentTypeName     = $CurrentTypeName 
            NewTypeName         = $NewTypeName
            Project             = $Project
            ExitCode            = $result.ExitCode
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {
            $actionLogObject.ActionText = 'Sucessfully renamed type "{0}" to new name "{1}".' -f $CurrentTypeName, $NewTypeName
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error renaming type "{0}" to new name "{1}".' -f $CurrentTypeName, $NewTypeName
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
               
}

<#
.SYNOPSIS
    Wrapper for the WITAdmin changefield command
#>
function Invoke-TFSWITAdmin_ChangeField
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipelineByPropertyName=$true)][string] $ReferenceName,
        [Parameter(ValueFromPipelineByPropertyName=$true)][string] $TargetName
    )  
            
    process
    {

        $Arguments = 'changefield /collection:"{0}" /n:"{1}" /name:"{2}" /noprompt' -f $TFSProjectCollectionUrl, $ReferenceName, $TargetName  
             
        $result = Invoke-TFSWITAdmin -Arguments $Arguments 

        $actionLogObject = New-Object PSObject -Property @{ 
            ReferenceName       = $ReferenceName 
            TargetName          = $TargetName
            ExitCode            = $result.ExitCode
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {

            $actionLogObject.ActionText = 'Sucessfully changed field "{0}" to new name "{1}".' -f $ReferenceName, $TargetName
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error changing field "{0}" to new name "{1}".' -f $ReferenceName, $TargetName
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
             
}
<#
.SYNOPSIS
    Wrapper for the WITAdmin ImportLinkType command
#>
function Invoke-TFSWITAdmin_ImportLinkType
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipelineByPropertyName=$true)][string] $LinkTypeFullName
    )

    process
    {

        $Arguments = 'importlinktype /collection:"{0}" /f:"{1}"' -f $TFSProjectCollectionUrl, $LinkTypeFullName  
             
        $result = Invoke-TFSWITAdmin -Arguments $Arguments 

        $actionLogObject = New-Object PSObject -Property @{ 
            LinkTypeFullName    = $LinkTypeFullName 
            ExitCode            = $result.ExitCode
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {

            $actionLogObject.ActionText = 'Sucessfully imported link type "{0}".' -f $LinkTypeFullName
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error importing link type "{0}".' -f $LinkTypeFullName
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
             
}

<#
.SYNOPSIS
    Wrapper for the WITAdmin Import Process Config file command
#>
function Invoke-TFSWITAdmin_ImportProcessConfig
{
    [CmdletBinding()]
    param ( 
        [string] $TFSProjectCollectionUrl = 'http://localhost:8080/tfs/DefaultCollection',
        [Parameter(ValueFromPipeline=$true)][string] $Project,
        [string] $FileName
    )

    process
    {

        $Arguments = 'importprocessconfiguration /collection:"{0}" /p:"{1}" /f:"{2}"' -f $TFSProjectCollectionUrl, $Project, $FileName  
             
        $result = Invoke-TFSWITAdmin -Arguments $Arguments 

        $actionLogObject = New-Object PSObject -Property @{ 
            FileName            = $FileName 
            TFSProject          = $Project 
            ExitCode            = $result.ExitCode
            ActionText          = $null
            Status              = $null
            StandardOutput      = $result.StandardOutput -replace "`t|`n|`r",''
            StandardErrorOutput = $result.StandardErrorOutput -replace "`t|`n|`r",''
            Timestamp           = (Get-Date).ToString()
        }   
                        
        if ($result.StandardOutput) 
        {

            $actionLogObject.ActionText = 'Sucessfully imported Process Configuration file "{0}".' -f $FileNme
            $actionLogObject.Status = 'OK'
            Write-Verbose ($actionLogObject.ActionText)
        }
        else
        {
            $actionLogObject.ActionText = 'Error importing Process Configuration file "{0}".' -f $FileName
            $actionLogObject.Status = 'Error'
            Write-Verbose ($actionLogObject.ActionText)
        } 
                    
        Write-Output($actionLogObject)         

    }
             
}