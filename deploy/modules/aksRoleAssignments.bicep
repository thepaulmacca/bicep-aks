@description('The name of the AKS cluster')
param clusterName string

@description('The Azure AD group that will be granted the highly privileged cluster-admin role')
param clusterAdminAadGroupObjectId string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-07-01' existing = {
  name: clusterName
}

@description('This is the built-in Azure Kubernetes Service RBAC Cluster Admin role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-rbac-cluster-admin')
resource aksRbacClusterAdminRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
}

@description('Assign the Azure Kubernetes Service RBAC Cluster Admin role to the cluster admin AAD group')
resource clusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  scope: aksCluster
  name: guid(resourceGroup().id, clusterAdminAadGroupObjectId, aksRbacClusterAdminRoleDefinition.id)
  properties: {
    roleDefinitionId: aksRbacClusterAdminRoleDefinition.id
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

@description('This is the built-in Azure Kubernetes Service Cluster User role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-cluster-user-role')
resource aksClusterUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
}

@description('Assign the Azure Kubernetes Service Cluster User role to the cluster admin AAD group')
resource clusterUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  scope: aksCluster
  name: guid(resourceGroup().id, clusterAdminAadGroupObjectId, aksClusterUserRoleDefinition.id)
  properties: {
    roleDefinitionId: aksClusterUserRoleDefinition.id
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

@description('This is the built-in Monitoring Metrics Publisher role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-metrics-publisher')
resource monitoringMetricsPublisherRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
}

@description('Assign the Monitoring Metrics Publisher role to the OMS Agent identity. This allows it to push alerts')
resource monitoringMetricsPublisherRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(resourceGroup().id, aksCluster.id, monitoringMetricsPublisherRoleDefinition.id)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinition.id
    principalId: aksCluster.properties.addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}
