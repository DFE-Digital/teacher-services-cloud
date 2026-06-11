
Set-AzContext -Subscription "s189-teacher-services-cloud-development"

$rg = "s189d01-storage-test"
$location = "uksouth"
$accountName = "s189d01tstimut"
$containerName = "database-backup"

New-AzResourceGroup -Name $rg -Location $location

$account = New-AzStorageAccount `
    -ResourceGroupName $rg `
    -Name $accountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2

New-AzStorageContainer `
    -Name $containerName `
    -Context $account.Context




<#
    Set-AzRmStorageContainerImmutabilityPolicy `
        -ResourceGroupName $rg `
        -StorageAccountName $accountName `
        -ContainerName $containerName `
        -ImmutabilityPeriod 1 `
        -ExtendPolicy `
        -ErrorAction Break

#>
