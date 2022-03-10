@description('The azure region into which the resources should be deployed')
param location string

@description('The name of the AKS cluster')
param clusterName string

@description('The Azure AD group that will be granted the highly privileged cluster-admin role')
param clusterAdminAadGroupObjectId string

@description('The resource group where the log analytics workspace is located')
param logAnalyticsWorkspaceResourceGroup string

@description('The name of the log analytics workspace')
param logAnalyticsWorkspaceName string

var kubernetesVersion = '1.22.6'
var nodeResourceGroupName = '${resourceGroup().name}-nodes'
var aksDiagnosticSettingsName = 'route-logs-to-log-analytics'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroup)
  name: logAnalyticsWorkspaceName
}

resource aks 'Microsoft.ContainerService/managedClusters@2021-09-01' = {
  name: clusterName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {
      adminGroupObjectIDs: [
        clusterAdminAadGroupObjectId
      ]
      enableAzureRBAC: true
      managed: true
      tenantID: subscription().tenantId
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
        }
      }
    }
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 1
        enableAutoScaling: true
        maxCount: 2
        maxPods: 30
        minCount: 1
        mode: 'System' // setting this to system type for just k8s system services
        // nodeTaints: [
        //   'CriticalAddonsOnly=true:NoSchedule' // adding to ensure that only k8s system services run on these nodes
        // ]
        orchestratorVersion: kubernetesVersion
        osDiskSizeGB: 80
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        scaleDownMode: 'Delete'
        type: 'VirtualMachineScaleSets'
        upgradeSettings: {
          maxSurge: '33%'
        }
        vmSize: 'Standard_DS2_v2'
      }
    ]
    apiServerAccessProfile: {}
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      'expander': 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'node-image'
    }
    disableLocalAccounts: true
    dnsPrefix: clusterName
    enableRBAC: true
    kubernetesVersion: kubernetesVersion
    // linuxProfile: {
    //   adminUsername: 'adminUserName'
    //   ssh: {
    //     publicKeys: [
    //       {
    //         keyData: 'REQUIRED'
    //       }
    //     ]
    //   }
    // }
    networkProfile: {
      dnsServiceIP: '172.16.0.10' // Ip Address for K8s DNS
      dockerBridgeCidr: '172.18.0.1/16' // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime. Not used by AKS or Docker and is only cluster-routable. Cluster IP based addresses are allocated from this range. Can be safely reused in multiple clusters
      loadBalancerProfile: json('null')
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      outboundType: 'loadBalancer'
      serviceCidr: '172.16.0.0/16'  // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem). Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables
    }
    nodeResourceGroup: nodeResourceGroupName
    podIdentityProfile: {
      enabled: true
      userAssignedIdentities: []
      userAssignedIdentityExceptions: [
        {
          name: 'flux-extension-exception'
          namespace: 'flux-system'
          podLabels: {
            'app.kubernetes.io/name': 'flux-extension'
          }
        }
      ]
    }
    securityProfile: {
      azureDefender: {
        enabled: true
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
      }
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
  }
}

resource fluxExtension 'Microsoft.KubernetesConfiguration/extensions@2021-09-01' = {
  name: 'flux'
  scope: aks
  properties: {
    autoUpgradeMinorVersion: true
    extensionType: 'microsoft.flux'
    releaseTrain: 'stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
        configurationProtectedSettings: {}
        configurationSettings: {
          'helm-controller.enabled': 'true'
          'source-controller.enabled': 'true'
          'kustomize-controller.enabled': 'true'
          'notification-controller.enabled': 'true'
          'image-automation-controller.enabled': 'true'
          'image-reflector-controller.enabled': 'true'
        }
      }
    }
  }
}

resource fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-01-01-preview' = {
  name: 'bootstrap'
  scope: aks
  properties: {
    configurationProtectedSettings: {}
    gitRepository: {
      repositoryRef: {
        branch: 'main'
      }
      syncIntervalInSeconds: 600
      timeoutInSeconds: 600
      url: 'https://github.com/fluxcd/flux2-kustomize-helm-example'
    }
    kustomizations: {
      infra: {
        path: './infrastructure'
        dependsOn: []
        timeoutInSeconds: 600
        syncIntervalInSeconds: 600
        prune: true
      }
      apps: {
        path: './apps/staging'
        dependsOn: [
          {
            kustomizationName: 'infra'
          }
        ]
        timeoutInSeconds: 600
        syncIntervalInSeconds: 600
        retryIntervalInSeconds: 600
        prune: true
      }
    }
    namespace: 'flux-system'
    scope: 'cluster'
    sourceKind: 'GitRepository'
  }
  dependsOn: [
    fluxExtension
  ]
}

resource aksDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aks
  name: aksDiagnosticSettingsName
  properties: {
    logs: [
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

output clusterName string = aks.name
