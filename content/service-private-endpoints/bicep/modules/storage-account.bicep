param parSuffix string
param parLocation string = resourceGroup().location
param parAllowPublicAccess bool = true
param parDefaultNetworkAction string = 'Allow'
param parVirtualNetworkRules array = []

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'sa${parSuffix}ne'
  location: parLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: parAllowPublicAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: parDefaultNetworkAction
      ipRules: []
      virtualNetworkRules: parVirtualNetworkRules
    }
  }

  resource saBlob 'blobServices@2021-06-01' = {
    name: 'default'
    properties: {}

    resource saBlobContainer 'containers@2021-06-01' = {
      name: 'test'
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

output outStorageAccountId string = sa.id
