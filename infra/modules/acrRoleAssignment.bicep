// modules/acrRoleAssignment.bicep
// Assigns ACR Pull role to a managed identity

param principalName string            // used as deterministic GUID seed
param principalId string
param acrResourceId string           // full ACR resourceId

@description('Full resourceId of the role definition for ACR Pull')
param roleDefinitionResourceId string = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'     // AcrPull role
)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrResourceId, principalName, roleDefinitionResourceId)  // deterministic
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
