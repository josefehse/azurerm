#break
#logon to azurerm 
#region basics
Add-AzureRmAccount
$VerbosePreference="Continue"
$rgName="DevOpsDemo"
$saName="devops04112016"
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



New-AzureRmResourceGroupDeployment -Name "DevOpsDeployment" -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/josefehse/azurerm/master/Nics.Json

break
