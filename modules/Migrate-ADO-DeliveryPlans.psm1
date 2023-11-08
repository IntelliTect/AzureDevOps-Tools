
function Start-ADODeliveryPlansMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter (Mandatory = $TRUE)] [String]$SourceOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$SourceProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$SourceHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$SourcePAT,
        [Parameter (Mandatory = $TRUE)] [String]$TargetOrgName, 
        [Parameter (Mandatory = $TRUE)] [String]$TargetProjectName, 
        [Parameter (Mandatory = $TRUE)] [Hashtable]$TargetHeaders,
        [Parameter (Mandatory = $TRUE)] [String]$TargetPAT
        
    )
    if ($PSCmdlet.ShouldProcess(
            "Target project $TargetOrg/$TargetProjectName",
            "Migrate DeliveryPlans from source project $SourceOrgName/$SourceProjectName")
    ) {
        Write-Log -Message ' '
        Write-Log -Message '---------------------------'
        Write-Log -Message '-- Migrate DeliveryPlans --'
        Write-Log -Message '---------------------------'
        Write-Log -Message ' '


        $sourceDeliveryPlans = (Get-DeliveryPlans -projectName $sourceProjectName -orgName $SourceOrgName -headers $SourceHeaders).Value
        $targetDeliveryPlans = (Get-DeliveryPlan -projectName $targetProjectName -orgName $TargetOrgName -headers $TargetHeaders).Value

        
        ForEach ($deliveryplan in $sourceDeliveryPlans) { 
            Write-Log -Message "Migrating DeliveryPlan: $($deliveryplan.name).."

            if ($null -ne ($targetDeliveryPlans | Where-Object { $_.name -ieq $deliveryplan.name } )) {
                Write-Log -Message "DeliveryPlan [$($deliveryplan.Name)] already exists in target.. "
                continue
            }
            
            try {

                $plan = Get-DeliveryPlan -ProjectName $sourceProjectName -OrgName $SourceOrgName -Headers $SourceHeaders -Id $deliveryplan.Id
                New-DeliveryPlan -projectName $targetProjectName -OrgName $targetOrgName -Headers $targetHeaders -Deliveryplan @{
                    "name"              = $plan.name
                    "description"       = $plan.description
                    "type"              = $plan.type
                    "properties"        = $plan.properties
                }

            } catch {
               Write-Log -Message "FAILED!" -LogLevel ERROR
               Write-Log -Message $_.Exception -LogLevel ERROR
               try {
                   Write-Log -Message ($_ | ConvertFrom-Json).message -LogLevel ERROR
               } catch {}
           }
        }
    }
}

function Get-DeliveryPlans([string]$OrgName, [string]$ProjectName, $Headers) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/work/plans?api-version=7.0"

    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

    return $results
}

function Get-DeliveryPlan([string]$OrgName, [string]$ProjectName, [string]$Id, $Headers) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/work/plans/$($id)?api-version=7.0"

    $results = Invoke-RestMethod -Method Get -uri $url -Headers $Headers

    return $results
}


function New-DeliveryPlan([string]$OrgName, [string]$ProjectName, $Headers, $DeliveryPlan) {
    $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/work/plans?api-version=7.0"

    $body = $deliveryPlan | ConvertTo-Json -Depth 10

    $results = Invoke-RestMethod -Method Post -uri $url -Headers $Headers -Body $body -ContentType "application/json"
    
    return $results
}


