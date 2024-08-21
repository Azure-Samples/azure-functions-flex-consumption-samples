// Parameters
@description('Specifies the name of the virtual network.')
param virtualNetworkName string

@description('Specifies the name of the subnet for the Service Bus private endpoint.')
param subnetName string

@description('Specifies the resource id of the Service Bus namespace.')
param sbNamespaceId string

@description('Specifies the location.')
param location string = resourceGroup().location

param tags object = {}


// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

// Private DNS Zones
resource sbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource sbPrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sbPrivateDnsZone
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
resource sbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'sbPrivateEndpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'sbPrivateEndpointConnection'
        properties: {
          privateLinkServiceId: sbNamespaceId
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

resource sbPrivateDnsZoneGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: sbPrivateEndpoint
  name: 'sbPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: sbPrivateDnsZone.id
        }
      }
    ]
  }
}
