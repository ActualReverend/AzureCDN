
<#PSScriptInfo

.VERSION 0.2

.GUID f05357ab-c502-4b1a-b784-75e0e927b5a0

.AUTHOR Bryan.Loveless@gmail.com

.COMPANYNAME 

.COPYRIGHT 2018

.TAGS Web

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


.PRIVATEDATA 

#>

<# 

.DESCRIPTION 
 Creates CDN Endpoint 

Required module:
Install-Module -Name AzureRM (or update-module)

#> 
Param()


# List of CDN commands in azure:  https://docs.microsoft.com/en-us/azure/cdn/cdn-manage-powershell



$ResourceGroupName = "Platform-Team"
$CDNProfileName = "DevCDNProfile"
$EndpointName = "DevCDNEndpoint" #.azureedge.net"
$WebsiteFQDN = "dev.blah.com"
$StorageName = "devcdnendpoint" # NO HYPENS, capitals, ect... should be close to $EndpontName
$Tag = @{Dept="IT"; Environment="Dev"}


$svcprincipal ="PUTYOURSTUFFHERE"
$Subscription = "PUTYOURSTUFFHERE"

$tenant = "PUTYOURSTUFFHERE"
$Location = "WestUS"


$SKU = "Standard_Microsoft"
$StorageSku = "Standard_LRS"
$OriginName = $EndpointName # "The name of the origin. For display only."  https://github.com/Azure/azure-powershell/pull/2687/commits/430f77a5e3dc0816ce61b69b7d18887fc10e04c4


$OriginHostname = ""  # STORAGE LOCATION, expectLIKE: https://sandboxcdn.blob.core.windows.net, Populated LATER when storage created ($Storageaccountinfo.PrimaryEndpoints.Blob)
$originPath = "" #blob "folder" it should look at, if it is inside of a folder in the storage blob

#$Credential = Get-Credential -Message "Enter your AZURE credentials" 
# CONVERT ABOVE TO MSI : https://azure.microsoft.com/en-us/blog/keep-credentials-out-of-code-introducing-azure-ad-managed-service-identity/

#$cred = Get-Credential -UserName $svcprincipal.ApplicationId -Message "Enter Password"
#Connect-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

Login-AzAccount -TenantId $tenant -Subscription $Subscription 


# BLAH is applicationID


# Import the module into the PowerShell session
Import-Module AzureRM
#Connect to AZURE
#Connect-AzureRmAccount -Credential $Credential -Subscription $Subscription

# Resolve-AzureRmError
###################################### need to create storage area for endpoint to use##################################

$Storageaccountinfo = (New-AzureRMStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Location $Location -SkuName $StorageSku -Kind BlobStorage -AccessTier Hot -Tag $Tag)
# to remove above:   Remove-AzureRmStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroupname
$OriginHostname = ($Storageaccountinfo.PrimaryEndpoints.Blob)   # expect like: https://devcdnendpoint.blob.core.windows.net/

# $Storageaccountinfo = get-azurermstorageaccount -ResourceGroupName $resourcegroupname -name $storagename 

#Storage account location: $Storageaccountinfo.PrimaryEndpoints.Blob

# create a container inside of the blob, that woudl be orgin path?  "Container" sets public access
$accountObject = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $Storageaccountinfo.StorageAccountName
$StorageContainer = New-AzureRmStorageContainer -StorageAccount $accountObject -ContainerName ($Storagename + "Container").ToLower() -PublicAccess Blob 



###########################haven't automated yet, so had to create the CDN manually: ############################################
# $CDNProfile = New-AzureRmCdnProfile -ProfileName $CDNProfileName -Location $Location -ResourceGroupName $ResourceGroupName -Sku $SKU 



########################Now create the CDN endpoint###########################
#Get CDN profile info
$CDNProfile = Get-AzureRmCdnProfile -ProfileName $CDNProfileName -ResourceGroupName $ResourceGroupName


# Create a new endpoint now that storage and profile are done

New-AzureRmCdnEndpoint -CdnProfile $CDNProfile -EndpointName $EndpointName  -Location $Location  -OriginHostName $OriginHostname `
    -OriginName $OriginName -Profilename ($CDNProfile.Name.ToString()) -ResourceGroupName $ResourceGroupName `
    -IsCompressionEnabled $True -IsHttpsAllowed $True -IsHttpAllowed $True -Tag $Tag

# parameter sets:  https://stackoverflow.com/questions/50685092/new-azurermvm-parameter-set-cannot-be-resolved-using-the-specified-named-param

New-AzureRmCdnEndpoint -EndpointName ($EndpointName.ToLower()) -CdnProfile $CDNProfile -OriginName $EndpointName.tolower() -OriginHostName $OriginHostname `
    -
    #-IsCompressionEnabled $True -IsHttpsAllowed $True -IsHttpAllowed $True -Tag $Tag

#################################### APPEARS TO WORK ABOVE!!! ################################### before orgin hostname, was $websiteFQDN . perhaps the slash at the end is confusing it?  
BREAK  # TO STOP THE SCRIPT, AS THIS BELOW IS WHAT I AM STILL WORKING ON


Resolve-AzureRmError -Last


# Retrieve availability
$availability = Get-AzureRmCdnEndpointNameAvailability -EndpointName "cdnposhdoc"

# If available, write a message to the console.
If($availability.NameAvailable) { Write-Host "Yes, that endpoint name is available." }
Else { Write-Host "No, that endpoint name is not available." }


# https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest
# az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID
Connect-AzureRmAccount -Credential $Credential -Tenant $tenant -ServicePrincipal 
