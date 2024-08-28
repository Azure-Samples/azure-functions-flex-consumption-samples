// Parameters
@description('Specifies the name of the virtual network.')
param virtualNetworkName string

@description('Specifies the name of the subnet which contains the virtual machine.')
param subnetName string

@description('Specifies the resource name of the Storage resource with an endpoint.')
param resourceName string

@description('Specifies the location.')
param location string = resourceGroup().location

param tags object = {}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: resourceName
}

var blobPrivateDNSZoneName = format('privatelink.blob.{0}', environment().suffixes.storage)

// Private DNS Zones
resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: blobPrivateDNSZoneName
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource blobPrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: blobPrivateDnsZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoints
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'blob-PrivateEndpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'blobPrivateEndpointConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

resource blobPrivateDnsZoneGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: blobPrivateEndpoint
  name: 'sbPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageBlobARecord'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

// Add private endpoint for table and queue

var tablePrivateDNSZoneName = format('privatelink.table.{0}', environment().suffixes.storage)

// Private DNS Zones
resource tablePrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: tablePrivateDNSZoneName
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource tablePrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tablePrivateDNSZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoints
resource tablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'table-PrivateEndpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'tablePrivateEndpointConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

resource tablePrivateDnsZoneGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: tablePrivateEndpoint
  name: 'stPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageTableARecord'
        properties: {
          privateDnsZoneId: tablePrivateDNSZone.id
        }
      }
    ]
  }
}

var queuePrivateDNSZoneName = format('privatelink.queue.{0}', environment().suffixes.storage)

// Private DNS Zones
resource queuePrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: queuePrivateDNSZoneName
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource queuePrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queuePrivateDNSZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoints
resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'queue-PrivateEndpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'queuePrivateEndpointConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

resource queuePrivateDnsZoneGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: queuePrivateEndpoint
  name: 'sqPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageQueueARecord'
        properties: {
          privateDnsZoneId: queuePrivateDNSZone.id
        }
      }
    ]
  }
}

