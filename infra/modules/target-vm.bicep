@description('Location for VM resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Admin username for the VM.')
param adminUsername string

@description('Admin password for the VM.')
@secure()
param adminPassword string

@description('Subnet ID for the VM NIC.')
param subnetId string

@description('URI to configure-winrm.ps1 script in a blob container.')
param configureWinrmScriptUri string

@description('Tags applied to resources.')
param tags object

var vmName = '${resourcePrefix}-vm'
var nicName = '${resourcePrefix}-nic'
var pipName = '${resourcePrefix}-pip'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${resourcePrefix}-${uniqueString(resourceGroup().id)}')
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource winrmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: '${vmName}/ConfigureWinRM'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File configure-winrm.ps1'
    }
    protectedSettings: {
      fileUris: [
        configureWinrmScriptUri
      ]
    }
  }
  dependsOn: [
    vm
  ]
}

@description('Resource ID of the VM.')
output vmId string = vm.id

@description('Name of the VM.')
output vmName string = vm.name

@description('Public IP address of the VM.')
output vmPublicIp string = publicIp.properties.ipAddress
