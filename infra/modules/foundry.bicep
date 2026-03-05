@description('Name of the Azure AI Foundry hub')
param hubName string

@description('Azure region — must support GPT-4o and Phi models')
param location string

@description('Resource tags')
param tags object = {}

// Storage account required by AI Foundry hub
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: take('st${replace(hubName, '-', '')}', 24)
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// Key Vault required by AI Foundry hub
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: take('kv-${hubName}', 24)
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
  }
}

// Azure OpenAI account for GPT-4o
resource openAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: take('oai-${hubName}', 63)
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: take('oai-${replace(hubName, '-', '')}', 24)
    publicNetworkAccess: 'Enabled'
  }
}

// GPT-4o model deployment via Azure OpenAI
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAI
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

// Azure AI Foundry hub workspace
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: hubName
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    storageAccount: storage.id
    keyVault: keyVault.id
    publicNetworkAccess: 'Enabled'
  }
}

// Phi-3.5-mini-instruct serverless endpoint (pay-as-you-go)
// Note: deploy from the Azure AI Foundry portal if the model is not yet available
// via Bicep in this region. The AI Hub workspace above provides the required environment.
// resource phiDeployment 'Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-04-01' = {
//   parent: aiHub
//   name: 'phi-35-mini'
//   location: location
//   tags: tags
//   sku: {
//     name: 'Consumption'
//   }
//   properties: {
//     authMode: 'Key'
//     modelSettings: {
//       modelId: 'azureml://registries/azureml/models/Phi-3.5-mini-instruct/versions/4'
//     }
//   }
// }

output hubId string = aiHub.id
output hubName string = aiHub.name
output openAIEndpoint string = openAI.properties.endpoint
output gpt4oDeploymentName string = gpt4oDeployment.name

