param parIdentityName string
param parLocationSuffix string = 'we'
param parLocation string = 'westeurope'

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uai-${parIdentityName}-${parLocationSuffix}'
  location: parLocation
}

output outIdentityId string = uai.id
output outIdentityName string = uai.name
output outIdentityPrincipalId string = uai.properties.principalId
output outIdentityClientId string = uai.properties.clientId
