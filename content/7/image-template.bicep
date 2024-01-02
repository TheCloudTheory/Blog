param parName string
param parLocation string = resourceGroup().location
param parLocationSuffix string = 'we'
param parImageName string
param runSuffix string = utcNow()
param parCustomizers array
param parStagingResourceGroupId string
param parIdentityId string

resource it 'Microsoft.VirtualMachineImages/imageTemplates@2023-07-01' = {
  name: 'it-${parName}-${parLocationSuffix}'
  location: parLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${parIdentityId}': {}
    }
  }
  properties: {
    stagingResourceGroup: parStagingResourceGroupId
    distribute: [
      {
        location: parLocation
#disable-next-line use-resource-id-functions
        imageId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/images/${parImageName}'
        runOutputName: '${parImageName}-${runSuffix}'
        type: 'ManagedImage'
      }
    ]
    source: {
      type: 'PlatformImage'
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    customize: parCustomizers
  }
}
