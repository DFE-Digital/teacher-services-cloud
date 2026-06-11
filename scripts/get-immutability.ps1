$result = @()
$outputFile = "storage_immutability_report.csv"

$storageAccounts = Get-AzStorageAccount
foreach($sa in $storageAccounts) {
    $sa.StorageAccountName

    $policy = Get-AzRmStorageContainerImmutabilityPolicy -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -ContainerName "database-backup" -ErrorAction SilentlyContinue
    if ($policy) {

        $result += [PSCustomObject]@{
                        SubscriptionId              = $subId
                        ResourceGroup               = $sa.ResourceGroupName
                        StorageAccount              = $sa.StorageAccountName
                        ContainerName               = "database-backup"
                        ImmutabilityPolicyState     = $policy.State
                        ImmutabilityPeriodDays      = $policy.ImmutabilityPeriodSinceCreationInDays
                        ETag                        = $policy.Etag
                    }
                }
}

$result | Export-Csv -Path $outputFile -NoTypeInformation
