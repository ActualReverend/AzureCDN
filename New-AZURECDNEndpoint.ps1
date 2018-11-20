
<#PSScriptInfo

.VERSION 1.0

.GUID f05357ab-c502-4b1a-b784-75e0e927b5a0

.AUTHOR Bryan.Loveless@gmail.com

.COMPANYNAME

.COPYRIGHT 2018

.TAGS Web Azure

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
 Creates CDN Endpoint.  Name will be named like "Department-Application-Environment" , so example: ITS-Publicassets-dev or ITS-Coreassets-dev.
 Inputs: Department name, Application Name, Environment

Required module:
Install-Module -Name AzureRM (or update-module)

#> 
Param(
    [Parameter(Mandatory=$False,Position=1)]
        [ValidateNotNullOrEmpty()]
        [parameter(ValueFromPipeline)]
	    [string]$ResourceGroupName = "", #  is another option

#	[Parameter(Mandatory=$True,Position=2)]
#       [ValidateNotNullOrEmpty()]
#        [parameter(ValueFromPipeline)]
#	    [string]$CDNProfileName = "",

#    [Parameter(Mandatory=$True,Position=3)]
#        [ValidateNotNullOrEmpty()]
#        [parameter(ValueFromPipeline)]
#	    [string]$EndpointName = "Cmsassets", 

	[Parameter(Mandatory=$True,Position=4)]
        [ValidateNotNullOrEmpty()]
        [parameter(ValueFromPipeline)]
	    [string]$WebsiteFQDN = "CMSassets-.g.g",

#    [Parameter(Mandatory=$True,Position=5)]
#        [ValidateLength(3,19)]
#        [parameter(ValueFromPipeline)]
#        [ValidateNotNullOrEmpty()]
#	    [string]$StorageName = "cmsassetsdevcdndpt", # NO HYPENS, capitals, ect... should be close to $EndpontName, BETWEEN 3 and 24 characters

    [Parameter(Mandatory=$True,Position=6)]
        [parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Dev','Test','Prod', 'dvop', ignorecase=$True)]
	    [string]$Environment = "dvop",

    [Parameter(Mandatory=$False,Position=7)]
        [parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3,5)]
        [string]$Dept = "IT",

	[Parameter(Mandatory=$True,Position=8,HelpMessage="Example: Application name, like PublicAssets or Coreassets")]
        [parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3,11)]
		[string]$AppName="DELETEME", # Example: PublicAssets or Coreassets

	[Parameter(Mandatory=$False,Position=9,HelpMessage="Example: ")]
        [parameter(ValueFromPipeline)]
		[string]$Originpath=$null, #blob "folder" it should look at, if it is inside of a folder in the storage blob

	[Parameter(Mandatory=$False,Position=10,HelpMessage="Who to chargeback?")]
        [parameter(ValueFromPipeline)]
		[string]$Speedchart="IT" #blob "folder" it should look at, if it is inside of a folder in the storage blob

    )


# List of CDN commands in azure:  https://docs.microsoft.com/en-us/azure/cdn/cdn-manage-powershell
# validation help: https://learn-powershell.net/2014/02/04/using-powershell-parameter-validation-to-make-your-day-easier/

# now need to suffix with random number, to keep entries unique accross all of powershell
$SharedRandomNumber = Get-Random -Maximum 9999


  
$CDNProfileName = $Dept + $AppName + $Environment + 'CDN' + $SharedRandomNumber  # ONLY CHANGE THIS WHEN CHANGING ENVIRONMENTS
$EndpointName = $Dept + $AppName + $Environment + 'Endpt' + $SharedRandomNumber #.azureedge.net"

$StorageName = ($Dept + $AppName + $Environment + 'str').ToLower() + $SharedRandomNumber # NO HYPENS, capitals, ect... should be close to $EndpontName, BETWEEN 3 and 24 characters

$Tag = @{Dept=$Dept; Environment=$Environment; Speedchart=$Speedchart}


$svcprincipal =""
$Subscription = ""

$tenant = ""
$Location = "West US"   ### YES, IT HAS A SPACE even though lots of other scripts don't.  


$SKU = "Standard_Akamai" # "Standard_Microsoft" 

$StorageSku = "Standard_LRS"
# $OriginName = $EndpointName # "The name of the origin. For display only."  https://github.com/Azure/azure-powershell/pull/2687/commits/430f77a5e3dc0816ce61b69b7d18887fc10e04c4
$OriginName = $WebsiteFQDN # This is the web application hostname

$OriginHostname = ($storagename + '.blob.core.windows.net')  # STORAGE LOCATION, expectLIKE: kjh.blob.core.windows.net


#$Credential = Get-Credential -Message "Enter your AZURE credentials" 
# CONVERT ABOVE TO MSI : https://azure.microsoft.com/en-us/blog/keep-credentials-out-of-code-introducing-azure-ad-managed-service-identity/

#$cred = Get-Credential -UserName $svcprincipal.ApplicationId -Message "Enter Password"
#Connect-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

Login-AzAccount -TenantId $tenant -Subscription $Subscription 





# Import the module into the PowerShell session
Import-Module AzureRM
#Connect to AZURE
#Connect-AzureRmAccount -Credential $Credential -Subscription $Subscription


###################################### need to create storage area for endpoint to use##################################

$Storageaccountinfo = (New-AzureRMStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Location $Location -SkuName $StorageSku -Kind BlobStorage -AccessTier Hot -Tag $Tag)
# to remove above:   Remove-AzureRmStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroupname
# $OriginHostname = ($Storageaccountinfo.PrimaryEndpoints.Blob)   # expect like: https://kljklt.blob.core.windows.net/

# $Storageaccountinfo = get-azurermstorageaccount -ResourceGroupName $resourcegroupname -name $storagename 

#Storage account location: $Storageaccountinfo.PrimaryEndpoints.Blob

# create a container inside of the blob, that woudl be orgin path?  "Container" sets public access
$accountObject = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $Storageaccountinfo.StorageAccountName


$StorageContainer = (New-AzureRmStorageContainer -StorageAccount $accountObject -ContainerName ($Storagename + "Container").ToLower() -PublicAccess Blob )



###########################create the CDN ############################################
$CDNProfile = New-AzureRmCdnProfile -ProfileName $CDNProfileName -Location $Location -ResourceGroupName $ResourceGroupName -Sku $SKU 



###################################################
#Get CDN profile info
#$CDNProfile = Get-AzureRmCdnProfile -ProfileName $CDNProfileName -ResourceGroupName $ResourceGroupName


# Create a new endpoint now that storage and profile are done

$CDNEndpoint = New-AzureRmCdnEndpoint -EndpointName ($EndpointName.ToLower()) -CdnProfile $CDNProfile -OriginName $EndpointName.tolower() -OriginHostName $OriginHostname -Tag $Tag 


# parameter sets:  https://stackoverflow.com/questions/50685092/new-azurermvm-parameter-set-cannot-be-resolved-using-the-specified-named-param


 



#Resolve-AzureRmError -Last


# Retrieve availability
#$availability = Get-AzureRmCdnEndpointNameAvailability -EndpointName "cdnposhdoc"

# If available, write a message to the console.
#If($availability.NameAvailable) { Write-Host "Yes, that endpoint name is available." }
#Else { Write-Host "No, that endpoint name is not available." }


# https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest
# az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID
#Connect-AzureRmAccount -Credential $Credential -Tenant $tenant -ServicePrincipal 
