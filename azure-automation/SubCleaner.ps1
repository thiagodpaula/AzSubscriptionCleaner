param(
[parameter(Mandatory=$false)]
[string] $environmentName = "AzureCloud",

[parameter(Mandatory=$false)]
[string] $tagEnvName = "Environment",

[parameter(Mandatory=$false)]
[string] $tagEnvValue = "DEV",

[parameter(Mandatory=$false)]
[string] $tagAgeName = "expireOn",

[parameter(Mandatory=$false)]
[string] $audit = "No",

[parameter(Mandatory=$false)]
[string] $azureRunAsConnectionName = "AzureRunAsConnection",

[parameter(Mandatory=$false)]
[string] $deleteEmptyRG = "Yes"
)

filter timestamp {"[$(Get-Date -Format G)]: $_"}

Write-Output "Script started." | timestamp

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName

    Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | out-null
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "... Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        write-host -Message $_.Exception
        throw $_.Exception
    }
}


$expResources= Search-AzGraph -Query "Resources | where tags.$tagEnvName=~('$tagEnvValue') | where todatetime(tags.$tagAgeName) < now() | project id, name, type, location, tags, resourceGroup"

if ($expResources) {
    $countRec=($expResources).count
    Write-Output "There are $countRec resources on $tagEnvName that has expired, i will delete this resources!" | timestamp
    foreach ($r in $expResources) {
        $rscName=$r.name
        Write-Output "Deleting Resource: $rscName" | timestamp
        Remove-AzResource -ResourceId $r.id -Force | out-null
    }
}
else{
    Write-Output "There are 0 resources on $tagEnvName, Congrats and have a nice day!"
}

if ($deleteEmptyRG -eq "Yes") {
    Start-Sleep -Seconds 5;
    $rgs = Get-AzResourceGroup;

    foreach ($resourceGroup in $rgs) {
        $name = $resourceGroup.ResourceGroupName;
        $count = (Get-AzResource | Where-Object { $_.ResourceGroupName -match $name }).Count;
        Write-host "O name e $name e o count e $count" | timestamp
        if ($count -eq 0) {
            if ($audit -eq "No") {
            Write-Output "There are $count empty resources in Resource Group $name, I will delete these for you!" | timestamp
            Write-Output "... Deleting Empty Resource Group: $name" | timestamp
            Remove-AzResourceGroup -Name $name -Force | out-null
            }
            elseif ($audit -eq "Yes"){
                Write-Output "There are $count empty resources in Resource Group $name, I don't touch for a while!" | timestamp
                Write-Output "... Planning Delete the Empty Resource Group: $name" | timestamp
            }
        }

    }
} else {
    Write-Output "The Resource Group CleanUp Function is Disabled!" | timestamp
}

Write-Output "Script finished." | timestamp