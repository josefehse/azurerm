Login-AzureRmAccount

$managedDiskType = 'StandardLRS'
$managedDiskCreateOption = 'Copy'
$diskName = "test-datadisk"
$diskCreateOption = 'Attach'
$resourceGroupName="test"
$location="eastus"
$snapshotName="vm1_snapshot"
$snapshot = Get-AzureRmSnapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
$diskConfig = New-AzureRmDiskConfig -AccountType $managedDiskType -Location $location -CreateOption $managedDiskCreateOption -SourceResourceId $snapshot.Id
$dataDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $resourceGroupName
add-AzureRmVMDataDisk -VM $vm -Name $diskName -Lun 2 -CreateOption Attach -ManagedDiskId $dataDisk.Id 
Update-AzureRmVM -VM $vm -ResourceGroupName $resourceGroupName