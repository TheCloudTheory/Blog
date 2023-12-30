using 'image-template-sub.bicep'

param parName = 'blog2'
param parLocation = 'westeurope'
param parIdentityName = 'it'
param parImageName = 'blog'
param parCustomizers = [
  {
    type: 'Shell'
    name: 'InstallUpgrades'
    inline: [
        'sudo apt install unattended-upgrades'
    ]
  }
]
