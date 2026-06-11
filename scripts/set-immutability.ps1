Set-AzContext -Subscription "s189-teacher-services-cloud-production"

$InputFile = "storage_immutability_update.csv"
$content = Import-Csv -Path $InputFile

foreach($data in $content){
    $data.StorageAccountName
    Set-AzRmStorageContainerImmutabilityPolicy `
        -ResourceGroupName $data.ResourceGroup `
        -StorageAccountName $data.StorageAccount `
        -ContainerName "database-backup" `
        -ImmutabilityPeriod 14 `
        -Etag $data.Etag `
        -ExtendPolicy `
        -ErrorAction Break
}
