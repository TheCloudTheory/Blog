param parLocation string = resourceGroup().location
param parAllowedStorageAccountId string

resource sep 'Microsoft.Network/serviceEndpointPolicies@2023-06-01' = {
  name: 'sep-ne'
  location: parLocation
  properties: {
    serviceEndpointPolicyDefinitions: [
      {
        name: 'sepdef-ne'
        properties: {
          service: 'Microsoft.Storage'
          serviceResources: [
            parAllowedStorageAccountId
          ]
          description: 'Storage service endpoint policy definition'
        }
      }
    ]
  }
}
