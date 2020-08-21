param(
    [parameter(Mandatory=$true)]
	[String] $resourceGroupName,
    [parameter(Mandatory=$true)]
	[String] $location,
	[parameter(Mandatory=$true)]
	[String] $keyVaultName,
	[parameter(Mandatory=$true)]
	[String] $sku,
	[parameter(Mandatory=$true)]
	[String] $userObjectId
)

$connectionName = "AzureRunAsConnection"
	try
	{
		$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

		Write-Verbose "Logging in to Azure..." -Verbose

		Add-AzureRmAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
	}
	catch {
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		} else{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}



$keyVault=Get-AzureRMKeyVault -VaultName $keyVaultName -ErrorVariable notPresent -ErrorAction SilentlyContinue

if (!$keyVault)
{
#creating Keyvault in azure
New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -SKU $SKU
# assigning Access policies to user
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForDeployment
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForTemplateDeployment
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForDiskEncryption
Set-AzureRmKeyVaultAccessPolicy `
		-VaultName $keyVaultName `
		-ResourceGroupName $resourceGroupName   `
		-PermissionsToCertificates list,get,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore `
        -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge `
        -PermissionsToSecrets list,get,set,delete,recover,backup,restore `
		-ServicePrincipalName "902f4cd2-7300-42d0-bc30-7918dce59bf8"
Set-AzureRmKeyVaultAccessPolicy `
        -VaultName $keyVaultName -BypassObjectIdValidation -ResourceGroupName $resourceGroupName `
        -ObjectId $userObjectId  `
        -PermissionsToCertificates list,get,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore `
        -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge `
        -PermissionsToSecrets list,get,set,delete,recover,backup,restore
   }
else 
{
Write-Output " keyVault already presented"

}
$uri="https://raw.githubusercontent.com/saisrinivas58/testjson/master/keyvaultdata.json"
$paramObj=Invoke-RestMethod -Uri $uri -Method Get
[String[]]$secretName= $paramObj.psobject.properties.name
 [String[]]$secretValue= $paramObj.psobject.properties.value
 
for($($i=0;$j=0);$i -le ($secretName.length - 1) -and $j -le ($secretValue.length - 1);$($i++;$j++))
 {
 Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName[$i] `
                             -SecretValue (ConvertTo-SecureString -String $secretValue[$j] -AsPlainText -Force)
}
