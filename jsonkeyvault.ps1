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
New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -SKU $sku
# assigning Access policies to user
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForDeployment
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForTemplateDeployment
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForDiskEncryption
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $resourceGroupName `
   -ObjectId $userObjectId `
   -PermissionsToCertificates list,get,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore `
   -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge `
   -PermissionsToSecrets list,get,set,delete,recover,backup,restore
 }
else 
{
Write-Output " keyVault already presented"

}
[object]$paramObj=Get-Content "https://raw.githubusercontent.com/saisrinivas58/testjson/master/keyvaultdata.json" | ConvertFrom-Json
#Write-Output $paramObj
[String[]]$secretName= $paramObj.psobject.properties.name
 Write-Output $secretName
 [String[]]$secretValue= $paramObj.psobject.properties.value
 Write-Output $secretValue
 
for($($i=0;$j=0);$i -le ($secretName.length - 1) -and $j -le ($secretValue.length - 1);$($i++;$j++))
 {
 Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName[$i] `
                             -SecretValue (ConvertTo-SecureString -String $secretValue[$j] -AsPlainText -Force)
}
