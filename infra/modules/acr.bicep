@description('Name of the Azure Container Registry')
param name string

@description('Azure region')
param location string

@description('ACR SKU (Basic for dev)')
@allowed(['Basic', 'Standard', 'Premium'])
param skuName string = 'Basic'

@description('Resource tags')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: skuName
  }
  tags: tags
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output acrId string = acr.id
output loginServer string = acr.properties.loginServer
output acrName string = acr.name
