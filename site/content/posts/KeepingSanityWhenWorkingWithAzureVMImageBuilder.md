---
title: "Keeping sanity when working with Azure VM Image Builder"
slug: keeping-sanity-when-working-with-azure-vm-image-builder
summary: 'It turned out, that my problems with Azure VM Image Builder are not over. In this blog post I am going to show you how misleading documentation can be, why Infrastructure-as-Code is a must, and what to do, when Azure is clearly messing with you.'
date: 2024-01-02T18:48:53+01:00
type: posts
draft: false
categories:
- Azure
tags:
- vm
- image
- builder
- managedidentity
- rbac
- bicep
series:
- Insights
---
The concept is simple - I want to use Azure VM Image Builder to build a custom virtual machine image. It doesn't matter what are the requirements, which alternative is the best, or what is the best recipe for American pancakes. I just expect, that managed services in cloud follow [principle of least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment). As it turns out, I have very high expectations.

## Short introduction
[Azure VM Image Builder](https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview?tabs=azure-powershell) is a managed Azure service, which is designed to simplify creation of custom VM images. In fact, it's just [Packer](https://www.packer.io/)-as-a-Service, which is a tool, that I like and respect. When you want to start working with that service, you just need to prepare an image template, which is basically an ARM Template / Bicep script, which you then send to Azure VM Image Builder. Such template may look just like this:
```
param parName string
param parLocation string = resourceGroup().location
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param runSuffix string = utcNow()
param parCustomizers array

resource it 'Microsoft.VirtualMachineImages/imageTemplates@2023-07-01' = {
  name: 'it-${parName}-${parLocationSuffix}'
  location: parLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    distribute: [
      {
        location: parLocation
#disable-next-line use-resource-id-functions
        imageId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/images/${parImageName}'
        runOutputName: '${parImageName}-${runSuffix}'
        type: 'ManagedImage'
      }
    ]
    source: {
      type: 'PlatformImage'
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    customize: parCustomizers
  }
}

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uai-${parIdentityName}-${parLocationSuffix}'
  location: parLocation
}
```
We could deploy such template like so and then run Image Builder to build an image:
```
az group create -l <some-location> -n <some-name>
az deployment group create --template-file .\image-template.bicep --parameters .\parameters.bicepparam -g <some-name>
az image builder run -n <template-name> -g <some-name>
```
It'll take some time (which depends on the performance of VM used by Azure VM Image Builder), but eventually, it'll create an image in selected location.
> To select a location of built image, you need to specify proper destination using `distribute` property. In the example below, an image would be created as standard managed image, which is a generic resource created within a resource group in a selected subscription.

To understand the service better, let's discuss one of its main concepts.

## Staging resource group
When an image is built, Azure VM Image Builder creates additional resource group called _staging_ to deploy resources needed to build an image. If you don't specify a custom name for that resource group, it'll be created like so:
![staging_resource_group](/images/7_1.PNG)
Yeah, your cloud architect or CCoE team is going to love you for keeping naming conventions! This is why we are allowed to specify the custom name using `stagingResourceGroup` property. To deploy everything with a single command, we could use subscription as deployment scope:
```
targetScope = 'subscription'

param parLocation string = 'westeurope'
param parName string
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param parCustomizers array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-rg'
  location: parLocation
}

resource staging_rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-staging-rg'
  location: parLocation
}

module it 'image-template.bicep' = {
  name: 'it'
  scope: resourceGroup(rg.name)
  params: {
    parLocation: parLocation
    parName: parName
    parIdentityName: parIdentityName
    parLocationSuffix: parLocationSuffix
    parImageName: parImageName
    parCustomizers: parCustomizers
    parStagingResourceGroupId: staging_rg.id
  }
}
```
Now, let's deploy it:
```
az deployment sub create --location westeurope --template-file .\image-template-sub.bicep --parameters .\parameters-sub.bicepparam
```
It'd be too good if everything works just like that, so instead of successful deployment we have this nice error:
```
{"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/.../providers/Microsoft.Resources/deployments/image-template-sub","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/.../resourceGroups/blog-ib-rg/providers/Microsoft.Resources/deployments/it","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"DeploymentFailed","target":"/subscriptions/.../resourceGroups/blog-ib-rg/providers/Microsoft.Resources/deployments/it","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/.../resourceGroups/blog-ib-rg/providers/Microsoft.VirtualMachineImages/imageTemplates/it-blog2-we","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"Unauthorized","message":"Not authorized to access the resource: /subscriptions/.../resourceGroups/blog-ib-staging-rg. Please check the user assigned identity has the correct permissions. For more details, go to https://aka.ms/azvmimagebuilderts."}]}]}]}]}}
```
All right - it worked for automatically created staging resource group, it doesn't work for custom one. You may wonder why - well, somebody designed the service that way. The root cause is actually pretty trivial - if you don't specify `stagingResourceGroup` in your template, Azure will create a role assignment for that random staging group for you:
![staging_resource_group_rbac](/images/7_2.PNG)
The same however is not performed for a custom resource group. Why? I have no idea. It doesn't matter - fixing that should be easy but before we make another mistake, let's read documentation.

## User-assigned identity permissions
There's a [detailed guide](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/image-builder) for Azure VM Image Builder, which outlines steps needed to deploy a template and build an image. In short, it advises you to create a custom role definition:
```
{
    "Name": "Azure Image Builder Service Image Creation Role",
    "IsCustom": true,
    "Description": "Image Builder access to create resources for the image build, you should delete or split out as appropriate",
    "Actions": [
        "Microsoft.Compute/galleries/read",
        "Microsoft.Compute/galleries/images/read",
        "Microsoft.Compute/galleries/images/versions/read",
        "Microsoft.Compute/galleries/images/versions/write",
        "Microsoft.Compute/images/write",
        "Microsoft.Compute/images/read",
        "Microsoft.Compute/images/delete"
    ],
    "NotActions": [
  
    ],
    "AssignableScopes": [
      "/subscriptions/<subscriptionID>/resourceGroups/<rgName>"
    ]
  }
```
If documentation says so, I'll do so. Let's add both definition and assignment to our Bicep code:
```
targetScope = 'subscription'

param parLocation string = 'westeurope'
param parName string
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param parCustomizers array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-rg'
  location: parLocation
}

resource staging_rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-ib-staging-rg'
  location: parLocation
}

resource rd 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('Azure Image Builder Service Image Creation Role')
  properties: {
    roleName: 'Azure Image Builder Service Image Creation Role'
    description: 'Allows Azure Image Builder to create images.'
    type: 'CustomRole'
    assignableScopes: [
      '/subscriptions/${subscription().subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
      }
    ]
  }
}

module uai 'identity.bicep' = {
  name: 'uai'
  scope: rg
  params: {
    parIdentityName: parIdentityName
    parLocation: parLocation
    parLocationSuffix: parLocationSuffix
  }
}

module assignment 'assignment.bicep' = {
  name: 'assignment'
  scope: rg
  params: {
    parRoleDefinitionId: rd.id
    parPrincipalId: uai.outputs.outIdentityPrincipalId
  }
}

module it 'image-template.bicep' = {
  name: 'it'
  dependsOn: [
    uai
    assignment
  ]
  scope: resourceGroup(rg.name)
  params: {
    parLocation: parLocation
    parName: parName
    parLocationSuffix: parLocationSuffix
    parImageName: parImageName
    parCustomizers: parCustomizers
    parStagingResourceGroupId: staging_rg.id
    parIdentityId: uai.outputs.outIdentityId
  }
}

```
As it turns out, it still doesn't work:
```
{"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/.../providers/Microsoft.Resources/deployments/image-template-sub","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/.../resourceGroups/blog-ib-rg/providers/Microsoft.Resources/deployments/it","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"DeploymentFailed","target":"/subscriptions/.../resourceGroups/blog-ib-rg/providers/Microsoft.Resources/deployments/it","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"Conflict","message":"Update/Upgrade of image templates is currently not supported. Please change the name of the template you are submitting. If you have previously tried to submit a template and it failed to provision, you must delete it first and then resubmit. For more information, go to https://aka.ms/azvmimagebuilderts."}]}]}]}}
```
The role assignment is created, but it seems, that Image Template cannot be updated if we failed to provision it properly. Let's delete it:
```
az image builder delete --name <template-name> --resource-group <resource-group-name>

(Unauthorized) Not authorized to access the resource: /subscriptions/.../resourceGroups/blog-ib-staging-rg. Please check the user assigned identity has the correct permissions. For more details, go to https://aka.ms/azvmimagebuilderts.
Code: Unauthorized
Message: Not authorized to access the resource: /subscriptions/.../resourceGroups/blog-ib-staging-rg. Please check the user assigned identity has the correct permissions. For more details, go to https://aka.ms/azvmimagebuilderts.
```
What a surprise! Because we didn't add proper role to our user-assigned identity, what caused provisioning of a template to fail, now we're unable to delete the template. I'd like to emphasize that, according to the documentation, we created a role, which should be enough for us, but the role itself is meant for managing VM images only. It's not useful when we want to create a custom staging group. How to delete our image template then?

## Adding missing role
In order to delete our custom staging group (or rather instruct Azure VM Image Builder to remove it as managed identity) we need to assign `Contributor` or comparable role to the staging resource group:
```
resource rd_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

module assignment_contributor 'assignment.bicep' = {
  name: 'assignment_contributor'
  scope: staging_rg
  params: {
    parRoleDefinitionId: rd_contributor.id
    parPrincipalId: uai.outputs.outIdentityPrincipalId
  }
}
```
Now, when you try to delete Image Template and deploy it once again, you should be able to do so.

## Conclusion
If you take a look at Image Template's reference, you'll see, that there's a note, which indicates, that custom resource group for staging resources will require the role we assigned manually:
![custom_staging_resource_group_rbac](/images/7_3.PNG)
While it's great, that we have that information in documentation, it'd great if more meaningful error came from API instead of just `Unauthorized`.