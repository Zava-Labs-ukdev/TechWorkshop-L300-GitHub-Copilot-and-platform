targetScope = 'resourceGroup'

@description('AZD environment name used for resource naming')
param environmentName string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
param appServiceSkuName string = 'B1'

@description('Container Registry SKU')
param acrSkuName string = 'Basic'

@description('Container image to deploy (updated after first ACR push)')
param containerImage string = 'zava-storefront:latest'

var abbrs = {
  logAnalytics: 'law'
  appInsights: 'appi'
  acr: 'acr'
  appServicePlan: 'asp'
  webApp: 'app'
  foundryHub: 'aih'
}

var tags = {
  environment: environmentName
  project: 'zava-storefront'
  managedBy: 'azd'
}

// --- Log Analytics Workspace ---
module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: '${abbrs.logAnalytics}-zavastore-${environmentName}'
    location: location
    tags: tags
  }
}

// --- Application Insights ---
module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  params: {
    name: '${abbrs.appInsights}-zavastore-${environmentName}'
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

// --- Azure Container Registry ---
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: '${abbrs.acr}zavastore${replace(environmentName, '-', '')}'
    location: location
    skuName: acrSkuName
    tags: tags
  }
}

// --- App Service Plan + Web App ---
module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    planName: '${abbrs.appServicePlan}-zavastore-${environmentName}'
    webAppName: '${abbrs.webApp}-zavastore-${environmentName}'
    location: location
    skuName: appServiceSkuName
    acrLoginServer: acr.outputs.loginServer
    containerImage: containerImage
    appInsightsConnectionString: appInsights.outputs.connectionString
    tags: tags
  }
}

// --- AcrPull Role Assignment (App Service identity → ACR) ---
module roleAssignment 'modules/roleAssignment.bicep' = {
  name: 'acrPullRoleAssignment'
  params: {
    acrId: acr.outputs.acrId
    principalId: appService.outputs.principalId
  }
}

// --- Azure AI Foundry Hub + Model Deployments ---
module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    hubName: '${abbrs.foundryHub}-zavastore-${environmentName}'
    location: location
    tags: tags
  }
}

// --- Outputs ---
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.acrName
output webAppName string = appService.outputs.webAppName
output webAppUrl string = 'https://${appService.outputs.defaultHostName}'
output appInsightsConnectionString string = appInsights.outputs.connectionString
output foundryHubName string = foundry.outputs.hubName
output openAIEndpoint string = foundry.outputs.openAIEndpoint
output gpt4oDeploymentName string = foundry.outputs.gpt4oDeploymentName
