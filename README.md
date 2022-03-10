# Bicep - AKS Cluster

This repo contains Bicep files that will deploy an AKS cluster - this is mainly used for testing scenarios, nothing too special here 😄

## Deploying the cluster

The first thing to do is validate the deployment, to make sure the syntax is correct:

```bash
az deployment sub validate \
   --location westeurope \
   --template-file ./deploy/main.bicep \
   --parameters <parameters>
```

Once validation has passed, confirm the deployment with `what-if`:

```bash
az deployment sub create \
   --location westeurope \
   --template-file ./deploy/main.bicep \
   --parameters <parameters> \
   --confirm-with-what-if
```

If all looks ok, type `y` to start the deployment
