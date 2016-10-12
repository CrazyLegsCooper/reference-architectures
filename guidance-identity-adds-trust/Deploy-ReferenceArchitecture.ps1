﻿#
# Deploy_ReferenceArchitecture.ps1
#
param(
  [Parameter(Mandatory=$true)]
  $SubscriptionId,

  [Parameter(Mandatory=$true)]
  $Location,
  
  [Parameter(Mandatory=$false)]
  [ValidateSet("Prepare", "Onpremise", "Infrastructure", "CreateVpn", "AzureADDS", "Workload", "PublicDmz", "PrivateDmz")]
  $Mode = "Prepare"
)

$ErrorActionPreference = "Stop"

$templateRootUriString = $env:TEMPLATE_ROOT_URI
if ($templateRootUriString -eq $null) {
  $templateRootUriString = "https://raw.githubusercontent.com/mspnp/template-building-blocks/master/"
}

if (![System.Uri]::IsWellFormedUriString($templateRootUriString, [System.UriKind]::Absolute)) {
  throw "Invalid value for TEMPLATE_ROOT_URI: $env:TEMPLATE_ROOT_URI"
}

Write-Host
Write-Host "Using $templateRootUriString to locate templates"
Write-Host

$templateRootUri = New-Object System.Uri -ArgumentList @($templateRootUriString)
$referenceArchitectureRootUri = New-Object System.Uri -ArgumentList @("https://raw.githubusercontent.com/mspnp/reference-architectures/master/")

$onPremiseVirtualNetworkGatewayTemplate = New-Object System.Uri -ArgumentList @($referenceArchitectureRootUri, "guidance-identity-adds-trust/templates/onpremise/virtualNetworkGateway.json")
$onPremiseConnectionTemplate = New-Object System.Uri -ArgumentList @($referenceArchitectureRootUri, "guidance-identity-adds-trust/templates/onpremise/connection.json")

$loadBalancerTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/loadBalancer-backend-n-vm/azuredeploy.json")
$virtualNetworkTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vnet-n-subnet/azuredeploy.json")
$virtualMachineTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/multi-vm-n-nic-m-storage/azuredeploy.json")
$dmzTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/dmz/azuredeploy.json")
$virtualNetworkGatewayTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vpn-gateway-vpn-connection/azuredeploy.json")
$virtualMachineExtensionsTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/virtualMachine-extensions/azuredeploy.json")

# Azure Onpremise Parameter Files
$onpremiseVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualNetwork.parameters.json")
$onpremiseVirtualNetworkDnsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualNetwork-adds-dns.parameters.json")
$onpremiseADDSVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-adds.parameters.json")
$onpremiseCreateAddsForestExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\create-adds-forest-extension.parameters.json")
$onpremiseAddAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\add-adds-domain-controller.parameters.json")
$onpremiseVirtualNetworkGatewayParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualNetworkGateway.parameters.json")
$onpremiseConnectionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\connection.parameters.json")

# Azure ADDS Parameter Files
$azureVirtualNetworkOnpremiseAndAzureDnsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetwork-with-onpremise-and-azure-dns.parameters.json")
$azureAddsVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualMachines-adds.parameters.json")
$azureAddAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\add-adds-domain-controller.parameters.json")
$gmsaExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\gmsa.parameters.json")
$joinAddsVmsToDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\adds-domain-join.parameters.json")


$azureVirtualNetworkGatewayParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetworkGateway.parameters.json")
$azureVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetwork.parameters.json")
$webLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-web.parameters.json")
$bizLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-biz.parameters.json")
$dataLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-data.parameters.json")
$managementParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualMachines-mgmt.parameters.json")
$privateDmzParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\dmz-private.parameters.json")
$publicDmzParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\dmz-public.parameters.json")


# Azure Onpremise Deployments
$onpremiseNetworkResourceGroupName = "ra-adtrust-onpremise-rg"

# Azure ADDS Deployments
$azureNetworkResourceGroupName = "ra-adtrust-network-rg"
$workloadResourceGroupName = "ra-adtrust-workload-rg"
$securityResourceGroupName = "ra-adtrust-security-rg"
$addsResourceGroupName = "ra-adtrust-adds-rg"

# Login to Azure and select your subscription
Login-AzureRmAccount -SubscriptionId $SubscriptionId | Out-Null

##########################################################################
# Deploy On premises network and on premise ADDS
##########################################################################

if ($Mode -eq "Onpremise" -Or $Mode -eq "Prepare") {
    $onpremiseNetworkResourceGroup = New-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName -Location $Location
    Write-Host "Creating onpremise virtual network..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkParametersFile

    Write-Host "Deploying ADDS servers..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-adds-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $onpremiseADDSVirtualMachinesParametersFile

    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
    Write-Host "Updating virtual network DNS servers..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-dns-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkDnsParametersFile

    Write-Host "Creating ADDS forest..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-adds-forest-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseCreateAddsForestExtensionParametersFile

    Write-Host "Creating ADDS domain controller..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-adds-dc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseAddAddsDomainControllerExtensionParametersFile
}

##########################################################################
# Deploy Vnet and VPN Infrastructure in cloud
##########################################################################

if ($Mode -eq "Infrastructure" -Or $Mode -eq "Prepare") {
    Write-Host "Creating ADDS resource group..."
    $azureNetworkResourceGroup = New-AzureRmResourceGroup -Name $azureNetworkResourceGroupName -Location $Location

    # Deploy network infrastructure
    Write-Host "Deploying virtual network..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-vnet-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $azureVirtualNetworkParametersFile

    # Deploy security infrastructure
    Write-Host "Creating security resource group..."
    $securityResourceGroup = New-AzureRmResourceGroup -Name $securityResourceGroupName -Location $Location

    Write-Host "Deploying jumpbox..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-jumpbox-deployment" -ResourceGroupName $securityResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $managementParametersFile
}

if ($Mode -eq "CreateVpn" -Or $Mode -eq "Prepare") {
    $onpremiseNetworkResourceGroup = Get-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName
    $azureNetworkResourceGroup = Get-AzureRmResourceGroup -Name $azureNetworkResourceGroupName

    Write-Host "Deploying Onpremise Virtual Network Gateway..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-vpn-gateway-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $onPremiseVirtualNetworkGatewayTemplate.AbsoluteUri -TemplateParameterFile $onpremiseVirtualNetworkGatewayParametersFile

    Write-Host "Deploying Azure Virtual Network Gateway..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-vpn-gateway-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualNetworkGatewayTemplate.AbsoluteUri -TemplateParameterFile $azureVirtualNetworkGatewayParametersFile

    Write-Host "Creating Onpremise connection..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-onpremise-connection-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $onPremiseConnectionTemplate.AbsoluteUri -TemplateParameterFile $onpremiseConnectionParametersFile
}

##########################################################################
# Deploy ADDS forest in cloud
##########################################################################

if ($Mode -eq "AzureADDS" -Or $Mode -eq "Prepare") {
    # Add the ADDS forest.
    $onpremiseNetworkResourceGroup = Get-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName

    # Deploy AD tier
    Write-Host "Creating ADDS resource group..."
    $addsResourceGroup = New-AzureRmResourceGroup -Name $addsResourceGroupName -Location $Location

    Write-Host "Deploying ADDS servers..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-adds-deployment" -ResourceGroupName $addsResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureAddsVirtualMachinesParametersFile

    # Join the domain
    Write-Host "Joining ADDS Vms to domain..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-adds-join-domain-deployment" `
        -ResourceGroupName $addsResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $joinAddsVmsToDomainExtensionParametersFile

    # Create DCs
    Write-Host "Creating ADDS domain controllers..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-adds-dc-deployment" `
        -ResourceGroupName $addsResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $azureAddAddsDomainControllerExtensionParametersFile

    $azureNetworkResourceGroup = Get-AzureRmResourceGroup -Name $azureNetworkResourceGroupName
    # Update DNS server to point to onpremise and azure
    Write-Host "Updating virtual network DNS..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-vnet-onpremise-azure-dns-deployment" `
        -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $azureVirtualNetworkOnpremiseAndAzureDnsParametersFile

}











##########################################################################
# Deployment workload and Dmz in cloud (optional for this guidance)
##########################################################################

if ($Mode -eq "Workload") {
    # Deploy workload tiers: RG, web, biz, and data

    Write-Host "Creating workload resource group..."
    $workloadResourceGroup = New-AzureRmResourceGroup -Name $workloadResourceGroupName -Location $Location

    Write-Host "Deploying web load balancer..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-web-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $webLoadBalancerParametersFile

    Write-Host "Deploying biz load balancer..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-biz-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $bizLoadBalancerParametersFile

    Write-Host "Deploying data load balancer..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-data-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $dataLoadBalancerParametersFile
}

if ($Mode -eq "PublicDMZ" -Or $Mode -eq "Prepare") {
    # Deploy Public DMZ 
    $azureNetworkResourceGroup = Get-AzureRmResourceGroup -Name $azureNetworkResourceGroupName

    Write-Host "Deploying public DMZ..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-dmz-public-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $dmzTemplate.AbsoluteUri -TemplateParameterFile $publicDmzParametersFile
}

if ($Mode -eq "PrivateDmz") {
    # Deploy Pirvate DMZs
    $azureNetworkResourceGroup = Get-AzureRmResourceGroup -Name $azureNetworkResourceGroupName

    Write-Host "Deploying private DMZ..."
    New-AzureRmResourceGroupDeployment -Name "ra-adtrust-dmz-private-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $dmzTemplate.AbsoluteUri -TemplateParameterFile $privateDmzParametersFile
}
