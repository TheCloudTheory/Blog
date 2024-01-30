param parLocation string = resourceGroup().location
param parAdminUsername string = 'thecloudtheory'
param parSubnetId string
param parSuffix string = ''

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: parSuffix == '' ? 'vm-ne' : 'vm-${parSuffix}-ne'
  location: parLocation
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: 'vm-ne'
      adminUsername: parAdminUsername
      adminPassword: 'ThisIsJustTest123___'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: parSuffix == '' ? 'nic-ne' : 'nic-${parSuffix}-ne'
  location: parLocation
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: parSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: parSuffix == '' ? 'pip-ne' : 'pip-${parSuffix}-ne'
  location: parLocation
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: parSuffix == '' ? 'nsg-ne' : 'nsg-${parSuffix}-ne'
  location: parLocation
  properties: {
    securityRules: [
      {
        name: 'ssh'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
