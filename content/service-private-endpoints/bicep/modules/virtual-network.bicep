param parLocation string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: 'vnet-ne'
  location: parLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'serviceendpoints'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ]
  }
}

output outSubnetId string = vnet.properties.subnets[0].id
output outSubnetServiceEndpointsId string = vnet.properties.subnets[1].id
