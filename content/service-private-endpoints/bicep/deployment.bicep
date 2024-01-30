targetScope = 'subscription'

param parLocation string = 'northeurope'

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-service-private-endpoint-ne'
  location: parLocation
}

module sa1 'modules/storage-account.bicep' = {
  scope: rg
  name: 'sa1'
  params: {
    parSuffix: 'public'
    parLocation: parLocation 
  }
}

module sa2 'modules/storage-account.bicep' = {
  scope: rg
  name: 'sa2'
  params: {
    parSuffix: 'se'
    parLocation: parLocation
    parDefaultNetworkAction: 'Deny'
    parVirtualNetworkRules: [
      {
        id: vnet.outputs.outSubnetServiceEndpointsId
        action: 'Allow'
      }
    ]
  }
}

module sa4 'modules/storage-account.bicep' = {
  scope: rg
  name: 'sa4'
  params: {
    parSuffix: 'se2'
    parLocation: parLocation
    parDefaultNetworkAction: 'Deny'
    parVirtualNetworkRules: [
      {
        id: vnet.outputs.outSubnetServiceEndpointsId
        action: 'Allow'
      }
    ]
  }
}

module sa3 'modules/storage-account.bicep' = {
  scope: rg
  name: 'sa3'
  params: {
    parSuffix: 'pe'
    parLocation: parLocation 
  }
}

module vnet 'modules/virtual-network.bicep' = {
  scope: rg
  name: 'vnet'
  params: {
    parLocation: parLocation 
  }
}

module vm 'modules/virtual-machine.bicep' = {
  scope: rg
  name: 'vm'
  params: {
    parLocation: parLocation 
    parSubnetId: vnet.outputs.outSubnetId
  }
}

module vm_se 'modules/virtual-machine.bicep' = {
  scope: rg
  name: 'vm_se'
  params: {
    parLocation: parLocation 
    parSubnetId: vnet.outputs.outSubnetServiceEndpointsId
    parSuffix: 'se'
  }
}

module sep 'modules/service-endpoint-policy.bicep' = {
  scope: rg
  name: 'sep'
  params: {
    parLocation: parLocation 
    parAllowedStorageAccountId: sa2.outputs.outStorageAccountId
  }
}
