targetScope = 'subscription'

@description('The azure region into which the resources should be deployed')
param location string = 'westeurope'

@description('The resource group where the log analytics workspace is located')
param logAnalyticsWorkspaceResourceGroup string

@description('The name of the log analytics workspace')
param logAnalyticsWorkspaceName string

@description('The Azure AD group that will be granted the highly privileged cluster-admin role')
param clusterAdminAadGroupObjectId string

var resourceGroupName = 'bicep-aks-rg'
var clusterName = 'bicep-aks'

@description('Create resource group')
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

@description('Deploy AKS cluster')
module aks 'modules/aks.bicep' = {
  name: 'aks-${uniqueString(subscription().subscriptionId)}'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    clusterName: clusterName
    logAnalyticsWorkspaceResourceGroup: logAnalyticsWorkspaceResourceGroup
    clusterAdminAadGroupObjectId: clusterAdminAadGroupObjectId
  }
}

@description('Deploy AKS RBAC role assignments')
module aksRoleAssignments 'modules/aksRoleAssignments.bicep' = {
  name: 'aks-role-assignments-${uniqueString(subscription().subscriptionId)}'
  scope: rg
  params: {
    clusterAdminAadGroupObjectId: clusterAdminAadGroupObjectId
    clusterName: aks.outputs.clusterName
  }
}
