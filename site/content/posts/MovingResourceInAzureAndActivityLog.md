---
title: "Moving resource in Azure - Activity Log"
slug: moving-resource-in-azure-activity-log
summary: 'Moving resources in Azure is an operation, which may be a really complex one, especially when you want to move IaaS components. Today I would like to talk about one of side-effects of moving instances of your cloud resources - what happens to Activity Log entries.'
date: 2024-01-23T21:06:50+01:00
type: posts
draft: false
categories:
- Azure
tags:
- azure
- azureresourcemanager
- activitylog
series:
- Insights
---
In this article we'll discuss implications of moving resources in Azure while focusing on Activity Log of a moved resource. As in some scenarios you may have lots of various processes, which are bases on entries of this particular log, preserving it will become crucial for day-to-day operations. Let's see what happens if we have an Azure service, and we decide to migrate it to another scope.

## Playground
In order to verify the scenario, I decided to create quite a simple infrastructure, which consists of two Azure resources:
* resource group
* Azure Storage account with a single container

When deployed, I can see, that there are some entries in my Activity Log:
![resource_move_1](/images/resource_move_1.PNG)

Looks good so far. Let's create a new resource group using Azure CLI:
```
az group create -n "rg-blob-move-2-we" -l westeurope
```
This resource group will be used as our target for the __move__ operation. Let's do that.

## Moving a resource
There are multiple ways to move a resource in Azure. In our exercise, we'll just go for Azure CLI to keep the operation simple:
```
az resource move --destination-group "rg-blob-move-2-we" --ids "/subscriptions/.../resourceGroups/rg-blob-move-rg/providers/Microsoft.Storage/storageAccounts/sablobmovewe"
```
After a moment, we should be able to see, that the storage account is in another resource group. Let's check its Activity Log.
> Remember, that moving a resource, which has a role assignment scoped to that resource, won't recreate that role. You need to apply all the assignments once again in order to restore access.

Once the __move__ operation is completed, we can verify if there's a trace of that operation in our Activity Log. Surprisingly, the log is almost empty:
![resource_move_1](/images/resource_move_2.PNG)

Even though we see nothing particular in our log, the moved resource still preserved its configuration and data plane. That's exactly the same storage account as we had previously - the only difference is lack of entries in Activity Log.

## Implications
When a resource is moved, initial entries of Activity Log imply, like it was recreated, not moved. This may cause some difficult time when trying to debug what happened (for instance - why some services lost access to your resource). It's also a bit confusing - suddenly you have a resource with no history. If there were important information inside the log, they're gone. If you're a developer, you could decide to just don't care. From the operational perspective, it may cause problems, especially if a resource is no longer compliant with your regulations.

## Solution
If Activity Log is an important feature of Azure resources for you, you may find exporting it quite important. Fortunately, it can be easily automated using _diagnostic settings_ - it works in the same way as you would configure exporting of logs & metrics from a service itself:
![resource_move_1](/images/resource_move_3.PNG)

In general, the only problem here is lack of proper warning when performing the __move__ operation. Sure, it requires you to ensure, that you won't be affected by broken resource ID of a moved resource, but there's no information, that you'll lose activity log as well. This is why proper management of this log becomes crucial in certain scenarios - if you fail to properly export and save it, you may quite easily erase all the history of a resource with no possibility to restore it.