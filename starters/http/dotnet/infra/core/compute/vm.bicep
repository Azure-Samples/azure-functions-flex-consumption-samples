// Declare params
@description('Name of the virtual machine:')
param virtualMachineName string = 'sb-vnet-vm'

@description('The virtual machine size.')
param virtualMachineSize string = 'Standard_D2s_v5'

@description('The Windows version for the VM')
param OSVersion string = '2022-Datacenter'

@description('Name of the virtual machine subnet')
param VMsubnetId string

@description('The admin user name of the VM')
param adminUsername string = 'sb-vnet-vm-user'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Network Security Group')
param networkSecurityGroupName string = '${virtualMachineName}-nsg'

@description('vault reference for admin password')
@secure()
param adminpassword string 

// Declare vars
var networkSecurityGroupRules = [
]
var publicIpAddressName = '${virtualMachineName}-publicip'
var publicIpAddressType = 'Dynamic'
var publicIpAddressSku = 'Basic'
var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var networkInterfaceName = '${virtualMachineName}-nic'

// Declare resources
resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
  sku: {
    name: publicIpAddressSku
  }
}

resource networkSecurityGroup_resource 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource networkInterfaceName_resource 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: VMsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
            properties: {
            }
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroup_resource
    publicIpAddressName_resource
  ]
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName_resource.id
          properties: {
          }
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminpassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
  }
}
