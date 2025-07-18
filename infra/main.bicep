targetScope = 'subscription'

// ───────────────────────── Parameters ──────────────────────────
param resourceGroupName string = 'trading'
param location string = 'eastasia'
param aksClusterName string = 'sre-trading-aks'
// param sqlServerName string = 'sretradingsql'
// param sqlDbName string = 'tradingdb'
param redisName string = 'sre-trading-redis-prod'
// param frontDoorName string = 'sreTradingFD'
param keyVaultName string = 'sre-trading-kv-prod'
param vnetName string = 'sre-trading-vnet'
param acrName string = 'sretradingacr'

// ───────────────────── Resource Group (scope) ──────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: {
    Environment: 'Production'
    Project: 'Infrastructure'
  }
}

// ──────────────── User‑Assigned Managed Identities ─────────────
var tradeIdentityName = '${aksClusterName}-trade-identity'
var quoteIdentityName = '${aksClusterName}-quote-identity'

module tradeIdentity './modules/identity.bicep' = {
  name:  'deployTradeIdentity'
  scope: rg
  params: {
    name:     tradeIdentityName
    location: location
  }
}

module quoteIdentity './modules/identity.bicep' = {
  name:  'deployQuoteIdentity'
  scope: rg
  params: {
    name:     quoteIdentityName
    location: location
  }
}


// ─────────────── Child Modules (scoped to RG) ──────────────────
module vnet       './modules/vnet.bicep'        = {
  name: 'deployVnet'
  scope: rg
  params: {
    name: vnetName
    location: location
  }
}

module redis      './modules/redis.bicep'       = {
  name: 'deployRedis'    
  scope: rg
  params: { 
    name: redisName
    location: location
    subnetId: vnet.outputs.redisSubnetId
  }
}

module acr           './modules/acr.bicep'          = {
  name: 'deployAcr'
  scope: rg
  params: {
    name: acrName
    location: location
    sku: 'Standard'
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

module aks        './modules/aks.bicep'         = {
  name: 'deployAks'       
  scope: rg
  params: { 
    name: aksClusterName
    location: location
    subnetId: vnet.outputs.aksSubnetId
    userAssignedIdentityId: quoteIdentity.outputs.resourceId
  }
}
module keyVault   './modules/keyvault.bicep'    = {
  name: 'deployKeyVault'
  scope: rg
  params: { 
    name: keyVaultName
    location: location 
  } 
}

// ───────────── Existing Key Vault (for role scope) ─────────────
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: rg
}

// ─────────────────── Redis Connection Secret ──────────────────
module redisSecret './modules/redisSecret.bicep' = {
  name: 'deployRedisSecret'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    redisName: redisName
    secretName: 'redis-connection-string'
  }
  dependsOn: [ keyVault, redis ]
}

var kvSecretsUserRoleResourceId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

module tradeKvRole './modules/keyvaultRoleAssignment.bicep' = {
  name:  'assignTradeIdentityKvRole'
  scope: rg
  params: {
    principalName:        tradeIdentityName
    principalId:          tradeIdentity.outputs.principalId
    keyVaultResourceId:   kv.id
    roleDefinitionResourceId: kvSecretsUserRoleResourceId
  }
  dependsOn: [ keyVault ]
}

module quoteKvRole './modules/keyvaultRoleAssignment.bicep' = {
  name:  'assignQuoteIdentityKvRole'
  scope: rg
  params: {
    principalName:        quoteIdentityName
    principalId:          quoteIdentity.outputs.principalId
    keyVaultResourceId:   kv.id
    roleDefinitionResourceId: kvSecretsUserRoleResourceId
  }
  dependsOn: [ keyVault ]
}

// ─────────────────── ACR Role Assignment ───────────────────────
module quoteAcrRole './modules/acrRoleAssignment.bicep' = {
  name: 'assignAksAgentPoolAcrRole'
  scope: rg
  params: {
    principalName: '${aksClusterName}-agentpool'
    principalId: aks.outputs.agentPoolPrincipalId
    acrResourceId: acr.outputs.registryId
  }
}

// ─────────────────── Redis Connection Secret ──────────────────
module redisSecret './modules/redisSecret.bicep' = {
  name: 'deployRedisSecret'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    redisName: redisName
    secretName: 'redis-connection-string'
  }
  dependsOn: [ keyVault, redis ]
}

// ────────────────────────── Outputs ────────────────────────────
output aksClusterNameOut string = aks.outputs.clusterName
output redisHost string = redis.outputs.hostName
output keyVaultUri string = keyVault.outputs.vaultUri
output vnetId string = vnet.outputs.vnetId
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.registryName

output tradeApiIdentityClientId string = tradeIdentity.outputs.clientId
output tradeApiIdentityPrincipalId string = tradeIdentity.outputs.principalId
output quoteApiIdentityClientId string = quoteIdentity.outputs.clientId
output quoteApiIdentityPrincipalId string = quoteIdentity.outputs.principalId
output redisConnectionSecretUri string = redisSecret.outputs.secretUri
