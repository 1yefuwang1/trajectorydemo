@description('VNet name')
param name string

@description('Location for the VNet')
param location string = resourceGroup().location

@description('VNet address prefix')
param addressPrefix string = '10.0.0.0/16'

@description('AKS subnet address prefix')
param aksSubnetPrefix string = '10.0.0.0/22' // Increased size for AKS

@description('Redis subnet address prefix')
param redisSubnetPrefix string = '10.0.4.0/24'

// Network Security Group for AKS subnet
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${name}-aks-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAKSApiServer'
        properties: {
          description: 'Allow AKS API server traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowKubeletAPI'
        properties: {
          description: 'Allow Kubelet API traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '10250'
          sourceAddressPrefix: aksSubnetPrefix
          destinationAddressPrefix: aksSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowNodePortServices'
        properties: {
          description: 'Allow NodePort services'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '30000-32767'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          description: 'Allow HTTP traffic to AKS services'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Security Group for Redis subnet
resource redisNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${name}-redis-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRedisFromAKS'
        properties: {
          description: 'Allow Redis traffic from AKS subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6380'
          sourceAddressPrefix: aksSubnetPrefix
          destinationAddressPrefix: redisSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowRedisSSLFromAKS'
        properties: {
          description: 'Allow Redis SSL traffic from AKS subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6379'
          sourceAddressPrefix: aksSubnetPrefix
          destinationAddressPrefix: redisSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: aksSubnetPrefix
          networkSecurityGroup: {
            id: aksNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: 'redis-subnet'
        properties: {
          addressPrefix: redisSubnetPrefix
          networkSecurityGroup: {
            id: redisNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output aksSubnetId string = vnet.properties.subnets[0].id
output redisSubnetId string = vnet.properties.subnets[1].id
output aksNsgId string = aksNsg.id
output redisNsgId string = redisNsg.id
