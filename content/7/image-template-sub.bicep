targetScope = 'subscription'

param parLocation string = 'westeurope'
param parName string
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param parCustomizers array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-rg'
  location: parLocation
}

resource staging_rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-staging-rg'
  location: parLocation
}

resource rd 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('Azure Image Builder Service Image Creation Role')
  properties: {
    roleName: 'Azure Image Builder Service Image Creation Role'
    description: 'Allows Azure Image Builder to create images.'
    type: 'CustomRole'
    assignableScopes: [
      '/subscriptions/${subscription().subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
      }
    ]
  }
}

module uai 'identity.bicep' = {
  name: 'uai'
  scope: rg
  params: {
    parIdentityName: parIdentityName
    parLocation: parLocation
    parLocationSuffix: parLocationSuffix
  }
}

module assignment 'assignment.bicep' = {
  name: 'assignment'
  scope: rg
  params: {
    parRoleDefinitionId: rd.id
    parPrincipalId: uai.outputs.outIdentityPrincipalId
  }
}

resource rd_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

module assignment_contributor 'assignment.bicep' = {
  name: 'assignment_contributor'
  scope: staging_rg
  params: {
    parRoleDefinitionId: rd_contributor.id
    parPrincipalId: uai.outputs.outIdentityPrincipalId
  }
}

module it 'image-template.bicep' = {
  name: 'it'
  dependsOn: [
    uai
    assignment
    assignment_contributor
  ]
  scope: resourceGroup(rg.name)
  params: {
    parLocation: parLocation
    parName: parName
    parLocationSuffix: parLocationSuffix
    parImageName: parImageName
    parCustomizers: parCustomizers
    parStagingResourceGroupId: staging_rg.id
    parIdentityId: uai.outputs.outIdentityId
  }
}
