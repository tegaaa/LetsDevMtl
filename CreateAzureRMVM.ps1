# AzureRM Module
Find-Module AzureRM 
Find-Module AzureRM | Install-Module

Import-Module AzureRM
Get-Command -Module AzureRM
Install-AzureRM

# Login Interactively
$AccountData=Add-AzureRMAccount

# Store data away for later user
Get-AzureRMSubscription | export-clixml Subscription.xml
Get-AzureRMTenant | export-clixml Tenant.xml
# OR
$AccountData.Context.Tenant.TenantId | Set-Clipboard
$AccountData.Context.Subscription.SubscriptionId | Set-Clipboard

#Create Credentials
$Credential=Get-Credential –credential "<your credentials>"

$TenantID=$AccountData.Context.Tenant.TenantId
$SubscriptionID=$AccountData.Context.Subscription.SubscriptionId 

Add-AzureRMAccount –tenantid $TenantID –subscriptionid $SubscriptionID –credential $Credential

# Create new
# Resource Group
$RGName='LetsDevMtlVM'
$Location='eastus'

New-AzureRmResourceGroup -Name $RGName -Location $Location

# Storage Account
$SAName='letsdevmtlvmcon'
$AccountType='Standard_LRS'

New-AzureRmStorageAccount -Name $SAName -ResourceGroupName $RGName -Location $Location -Type $AccountType
$StorageURI=(Get-AzureRmStorageAccount -Name $SAName -ResourceGroupName $RGName).PrimaryEndpoints.blob.Host

# Create a script container in the storage account for later
New-AzureStorageContainer -name scripts -context $context -Permission blob

# Virtual Network
$VNAddressPrefix='10.0.0.0/16'
$VNName='letsdevmtlvn'

$SNName='letsdevmtlsn'
$SNAddressPrefix='10.0.0.0/24'

$Subnet=New-AzureRmVirtualNetworkSubnetConfig -Name $SNName -AddressPrefix $SNAddressPrefix
New-AzureRmVirtualNetwork -Name $VNName -ResourceGroupName $RGName -Location $location -AddressPrefix $VNAddressPrefix -Subnet $Subnet
$AzureNet=Get-AzureRmVirtualNetwork -Name $VNName -ResourceGroupName $RGName
$SubnetID=$AzureNet.Subnets[0].id

# Create AzureVM
# Base config
$VMName='LetsDevMTLVM1'
$VMSize='Basic_A0'
$AzureVM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize

# Add Network card
$PublicIPName='vip1'+$VMName
$PublicIP = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Name $PublicIPName -Location $Location -AllocationMethod Dynamic -DomainNameLabel $VMName.ToLower()
$NIC = New-AzureRmNetworkInterface -Force -Name $VMName -ResourceGroupName $RGName -Location $Location -SubnetId $subnetId -PublicIpAddressId $PublicIP.Id
$AzureVM = Add-AzureRmVMNetworkInterface -VM $AzureVM -Id $NIC.Id
                            
# Setup OS & Image
$user = 'LetsDevAdmin'
$password = 'P@ssw0rd$'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword)

#$Cred=Get-Credential -UserName $user -Message 'Please Enter the Password for the Azure Virtual Machine' 
$AzureVM = Set-AzureRmVMOperatingSystem -VM $AzureVM -Windows -ComputerName $VMname -Credential $cred


#Get list of publish & offers & skus
Get-AzureRMVMImagePublisher -location $Location
Get-AzureRMVMImageOffer -location $Location -PublisherName MicrosoftWindowsServer
Get-AzureRmVMImageSku -location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer

# Get Azure Template for VM
$Publisher='MicrosoftWindowsServer'
$SKU='2012-R2-Datacenter'
$Offer='WindowsServer'

$VMImage = (Get-AzureRmVMImage -Location $location -PublisherName $Publisher -Offer $Offer -Skus $Sku)[-1]
$AzureVM = Set-AzureRmVMSourceImage -VM $AzureVM -PublisherName $Publisher -Offer $Offer -Skus $Sku -Version $VMImage.Version

# Name the Physical Disk for the O/S, Define Caching status and target URI
$osDiskName = $VMname+'_osDisk'
$osDiskCaching = 'ReadWrite'
$osDiskVhdUri = 'https://'+$StorageURI+'/vhds/'+$vmname+'_os.vhd'

$AzureVM = Set-AzureRmVMOSDisk -VM $AzureVM -VhdUri $osDiskVhdUri -name $osDiskName -CreateOption fromImage -Caching $osDiskCaching
                              
# Create Virtual Machine
New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $AzureVM 

# Add an extension to a VM
Get-AzureVMAvailableExtension | Format-Table -Property ExtensionName, Publisher

# Get VM info
Get-AzureRmVM –ResourceGroupName $RGName –VMName $VMName

# Check if Extension exists
Get-AzureRmVMExtension –ResourceGroupName $RGName –VMName $VMName -Name "HelloWorld" -Status

# Get Storage account key1
$SAkey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -Name $SAName).Key1

# upload file in blogspace
$FileName = "D:\Temp\HelloWorld.ps1"
$context = New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $SAkey1
$file = gci $FileName
Set-AzureStorageBlobContent -Blob $file.Name -Container "scripts" -File $file.FullName -Context $context -Force

# Set new extension to the VM
Set-AzureRmVMCustomScriptExtension –ResourceGroupName $RGName –VMName $VMName -Name "HelloWorld" -Location $Location -TypeHandlerVersion "1.8" -FileName "HelloWorld.ps1" -ContainerName scripts -StorageAccountName $SAName -StorageAccountKey $SAkey1 -Run "HelloWorld.ps1" 

# Look at the message in the VM
Get-AzureRmVMExtension –ResourceGroupName $RGName –VMName $VMName -Name "HelloWorld" -Status

# Remove Extension
Remove-AzureRmVMCustomScriptExtension –ResourceGroupName $RGName –VMName $VMName -Name "HelloWorld" -Force

# With Parameters
Set-AzureRmVMCustomScriptExtension –ResourceGroupName $RGName –VMName $VMName -Name "HelloWorld" -Location $Location -TypeHandlerVersion "1.8" -FileName "HelloWorld.ps1" -ContainerName scripts -StorageAccountName $SAName -StorageAccountKey $SAkey1 -Run "HelloWorld.ps1" -Argument "-Loc Montreal" 

Remove-AzureRmResourceGroup -Name $RGName