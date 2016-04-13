#break
#logon to azurerm - azureadmin@josefehsehotmail.onmicrosoft.com
#region basics
Add-AzureRmAccount
$VerbosePreference="Continue"
$rgName="DevOpsDemo"
$saName="devops"
$StorageType="Standard_LRS"
$vnetname="devopsvnet"
$domName="devopsdomain"
$locName="East US"
$GatewaySubnetPrefix="10.1.0.0/28"
$DefaultSubnetPrefix="10.1.1.0/24"
$VNetAddressPrefix="10.1.0.0/16"
#endregion
#region Create Azure Resource Group
Write-Verbose "Creating resource group $rgname"
if ((Get-AzureRmResourceGroup -Name $rgName -ErrorAction SilentlyContinue) -eq $null)
{
    New-AzureRmResourceGroup -Name $rgName -Location $locname 
}
#endregion
#region Create storage account - 16 lowercase characters
Write-Verbose "Creating storage account $saName"
if ((Test-AzureName -Storage $saName) -eq $false)
{
    #Test-Azure name is false - good! Name is available!
    Write-Verbose "Creating storage account $saName (not in use)"
    $storageAcc=New-AzureRmStorageAccount -Name $saName -Location $locName -ResourceGroupName $rgName -Type $StorageType
}
else
{
    do
    {
        $saName=Read-Host -Prompt "Enter new Storage Account Name:"

    } while ((Test-AzureName -Storage $saName) -ne $false)
    Write-Verbose "Creating storage account $saName (not in use)"
    $storageAcc=New-AzureRmStorageAccount -Name $saName -Location $locName -ResourceGroupName $rgName -Type $StorageType
}
#endregion
#region Create vnet and subnets
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name “GatewaySubnet” -AddressPrefix $GatewaySubnetPrefix
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name “Servers” -AddressPrefix $DefaultSubnetPrefix
if (($vnet=Get-AzureRmVirtualNetwork -Name $vnetname -ResourceGroupName $rgName -ErrorAction SilentlyContinue) -eq $null)
{
    Write-Verbose "Creating Vnet $vnetname"
    $vnet=New-AzureRmVirtualNetwork -Name $vnetname -Location $locName -ResourceGroupName $rgName -AddressPrefix $VNetAddressPrefix -Subnet $subnet1,$subnet2
}
#endregion
break


#$mylocalnetwork="devopslocalnetwork"
$PublicIpName="devopspip"
$LBbackendName="LB-BackEnd"
$lbName="NRP-LB"
$nicName="devopsvm1nic"
$staticIP="10.1.1.5"
$avName="devopssavset"
#region Create Public IP
#public name
Test-AzureRmDnsAvailability -DomainQualifiedName $domName -Location $locName
#Create public IP for LB
if ((Get-AzureRmPublicIpAddress -name $PublicIpName -ResourceGroupName $rgName -ErrorAction SilentlyContinue) -eq $null)
{
    Write-Verbose "Creating public ip PublicIP"
    $publicIP = New-AzureRmPublicIpAddress -Name $PublicIpName -ResourceGroupName $rgName -Location $locName –AllocationMethod Static -DomainNameLabel $domName 
}
#endregion
#region Create the LoadBalancer
Write-verbose "Creating Load balancer configuration requirements"
$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name LB-Frontend -PublicIpAddress $publicIP 
$beaddresspool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $LBbackendName

$healthProbe = New-AzureRmLoadBalancerProbeConfig -Name HealthProbe -RequestPath 'iisstart.htm' -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2
#Creates two inbound RDP Rules, using external ports 3441 and 3442, respectively
$inboundNATRule1= New-AzureRmLoadBalancerInboundNatRuleConfig -Name RDP1 -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389
$inboundNATRule2= New-AzureRmLoadBalancerInboundNatRuleConfig -Name RDP2 -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3442 -BackendPort 3389
#Create a Rule config to direct port 80 to LB Nodes
$lbrule = New-AzureRmLoadBalancerRuleConfig -Name HTTP -FrontendIpConfiguration $frontendIP -BackendAddressPool  $beAddressPool -Probe $healthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80

if (($NRPLB=Get-AzureRmLoadBalancer -Name $lbName -ResourceGroupName $rgName -ErrorAction SilentlyContinue ) -eq $null)
{
    Write-Verbose "Creating load balancer $lbName"
    $NRPLB = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $lbName -Location $locName -FrontendIpConfiguration $frontendIP -InboundNatRule $inboundNATRule1,$inboundNatRule2 -LoadBalancingRule $lbrule -BackendAddressPool $beAddressPool -Probe $healthProbe
}
#endregion
#region Create NIC and assign an internal IP

#$pip = New-AzureRmPublicIpAddress -Name $nicName -ResourceGroupName $rgName -Location $locName -AllocationMethod Dynamic
Write-Verbose "Creating NIC $nicName with IP $staticIP"
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $locName `
     -Subnet $vnet.Subnets[1] -PrivateIpAddress $staticIP -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] `
     -LoadBalancerInboundNatRule $nrplb.InboundNatRules[0] -Force
#endregion

#region Create an availability set
Write-Verbose "Creating Availability set $avName"
$avSet=New-AzureRmAvailabilitySet –Name $avName –ResourceGroupName $rgName -Location $locName
#endregion

#region Finally create the VM
$vmName="cloudrsvm1"
$vmSize="Standard_A2"
$vm=New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avSet.Id
#disk
$diskSize=80
$diskLabel="OS"
$diskName="cloudrsvm01-DISK1"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
#SKU
$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter"
$cred=Get-Credential -Message "Type the name and password of the local administrator account."
$vm=Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm=Set-AzureRmVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

$vm=Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $vhdURI -CreateOption fromImage
Write-Verbose "Finally creating VM $vmName"
New-AzureRmVM -ResourceGroupName $rgName -Location $locName -VM $vm
#endregion

#region Create VNIC for second VM
$nicName="cloudrsvm2nic"
$staticIP="10.1.1.6"
#$pip = New-AzureRmPublicIpAddress -Name $nicName -ResourceGroupName $rgName -Location $locName -AllocationMethod Dynamic
Write-Verbose "Creating NIC $nicName with IP $staticIP"
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $locName `
     -Subnet $vnet.Subnets[1] -PrivateIpAddress $staticIP -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] `
     -LoadBalancerInboundNatRule $nrplb.InboundNatRules[1] -Force
#endregion

#region Create Second VM
$vmName="cloudrsvm2"
$vmSize="Standard_A2"
$vm=New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avSet.Id

#disk
$diskSize=80
$diskLabel="OS"
$diskName="cloudrsvm02-DISK1"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
#Add-AzureRmVMDataDisk -VM $vm -Name $diskLabel -DiskSizeInGB $diskSize -VhdUri $vhdURI  -CreateOption empty
#SKU
$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter"
$cred=Get-Credential -Message "Type the name and password of the local administrator account."
$vm=Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm=Set-AzureRmVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

$vm=Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $vhdURI -CreateOption fromImage
Write-Verbose "Creating VM $vmName"
New-AzureRmVM -ResourceGroupName $rgName -Location $locName -VM $vm
#endregion



