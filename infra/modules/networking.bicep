@description('Location for networking resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Public IP/CIDR allowed to access RDP and WinRM on the VM.')
param deployerPublicIp string

@description('Tags applied to resources.')
param tags object

var vnetName = '${resourcePrefix}-vnet'
var vmSubnetName = 'vm-subnet'
var functionSubnetName = 'function-subnet'

resource vmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${resourcePrefix}-vm-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: deployerPublicIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-WinRM'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5986'
          sourceAddressPrefix: deployerPublicIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource functionNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${resourcePrefix}-func-nsg'
  location: location
  tags: tags
  properties: {}
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: '10.10.1.0/24'
          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
      {
        name: functionSubnetName
        properties: {
          addressPrefix: '10.10.2.0/24'
          networkSecurityGroup: {
            id: functionNsg.id
          }
        }
      }
    ]
  }
}

@description('Virtual network resource ID.')
output vnetId string = vnet.id

@description('Subnet ID for the VM.')
output vmSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, vmSubnetName)

@description('Subnet ID for the Function App.')
output functionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, functionSubnetName)
