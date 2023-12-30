targetScope = 'subscription'

param parLocation string = 'westeurope'
param parName string
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param parCustomizers array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-rg'
  location: parLocation
}

module it 'image-template.bicep' = {
  name: 'it'
  scope: resourceGroup(rg.name)
  params: {
    parLocation: parLocation
    parName: parName
    parIdentityName: parIdentityName
    parLocationSuffix: parLocationSuffix
    parImageName: parImageName
    parCustomizers: parCustomizers
  }
}
