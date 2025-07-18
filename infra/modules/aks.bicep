// modules/aks.bicep
// Minimal AKS cluster with managed identity (no servicePrincipalProfile needed).

param name          string
param location      string
param subnetId      string
param userAssignedIdentityId string
@minValue(1)
param agentCount    int    = 3
param nodeVmSize    string = 'Standard_D4s_v5'
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'
param serviceCidr string = '10.1.0.0/16' // Default to a non-overlapping CIDR
param dnsServiceIP string = '10.1.0.10' // Must be within serviceCidr

// AKS managed cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-03-01' = {
  name:     name
  location: location
  sku: {
    name: 'Base'
    tier: 'Standard'
  }

  // Use user-assigned managed identity
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }

  properties: {
    dnsPrefix: name
    enableRBAC: true

    networkProfile: {
      networkPlugin: networkPlugin
      loadBalancerSku: 'standard'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
    }

    agentPoolProfiles: [
      {
        name:   'agentpool'
        type:   'VirtualMachineScaleSets'
        mode:   'System'
        count:  agentCount
        vmSize: nodeVmSize
        osType: 'Linux'
        maxPods: 110
        vnetSubnetID: subnetId
      }
    ]
  }
}

// Outputs
output clusterName  string = aksCluster.name
output agentPoolPrincipalId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
