// modules/acr.bicep
// Azure Container Registry module

param name string
param location string = resourceGroup().location

@description('The SKU of the container registry')
@allowed([
  'Basic'
  'Standard' 
  'Premium'
])
param sku string = 'Standard'

@description('Enable admin user for the container registry')
param adminUserEnabled bool = false

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
  }
}

// Outputs
output registryId string = acr.id
output registryName string = acr.name
output loginServer string = acr.properties.loginServer
