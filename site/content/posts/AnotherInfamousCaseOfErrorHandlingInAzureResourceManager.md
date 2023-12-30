---
title: "Another infamous case of error handling in Azure Resource Manager"
summary: "Just recently I started working with Azure VM Image Builder to find the optimal solution for a business case I'm working on. As always, when working with Azure, time needed to complete a task depends not on the technical complexity, but rather on how mean Azure Resource Manager will be for a particular scenario."
date: 2023-12-29T13:16:57+01:00
type: posts
draft: false
categories:
- Azure
tags:
- azure
- azureresourcemanager
- arm
- arm-templates
- bicep
series:
- Insights
---
Azure Resource Manager is quite infamous for its error handling, especially when working with managed services, which abstract away lots of underlying infrastructure. You may deploy the simplest template possible, and still be stuck for hours because the error is just **500 Internal Server Error**. In such cases, you may either contact support (what's ) or just try to ask Google / SO / ChatGPT. The former is going to take days unless you have a dedicated, premium support plan. The latter is just a plain luck. As the last resort, you can just try to debug the problem by yourself. Unfortunately, the last option is what works the best for most of the problems I faced.

Let's see how "helpful" Azure Resource Manager can be using Azure VM Image Builder as example.

## Writing a template
To deploy an image template, which is used by Azure VM Image Builder, you need a JSON or Bicep file. Such a file describes metadata of an image, VM profile and customizers (actions taken to install and configure OS and software). The whole process is described in details [here](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/image-builder), so I'm not going to go into details of the service itself, but rather use an example from the documentation as a reference. 

### Reviewing example from documentation
The documentation uses the following [example](https://raw.githubusercontent.com/azure/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json) to explain how you can deploy and customize an image template:
```
{
    "type": "Microsoft.VirtualMachineImages/imageTemplates",
    "apiVersion": "2020-02-14",
    "location": "<region>",
    "dependsOn": [],
    "tags": {
        "imagebuilderTemplate": "windows2019",
        "userIdentity": "enabled"
    },
    "identity": {
        "type": "UserAssigned",
                "userAssignedIdentities": {
                "<imgBuilderId>": {}
                    
            }
    },
    "properties": {
        "buildTimeoutInMinutes" : 100,
        "vmProfile": 
            {
            "vmSize": "Standard_D2_v2",
            "osDiskSizeGB": 127
        },
        "source": {
            "type": "PlatformImage",
                "publisher": "MicrosoftWindowsServer",
                "offer": "WindowsServer",
                "sku": "2019-Datacenter",
                "version": "latest"  
        },
        "customize": [
            {
                "type": "PowerShell",
                "name": "CreateBuildPath",
                "runElevated": false,
                "scriptUri": "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/testPsScript.ps1"
            },
            {
                "type": "WindowsRestart",
                "restartCheckCommand": "echo Azure-Image-Builder-Restarted-the-VM  > c:\\buildArtifacts\\azureImageBuilderRestart.txt",
                "restartTimeout": "5m"
            },
            {
                "type": "File",
                "name": "downloadBuildArtifacts",
                "sourceUri": "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/exampleArtifacts/buildArtifacts/index.html",
                "destination":"c:\\buildArtifacts\\index.html"
            },

            {
                "type": "PowerShell",
                "name": "settingUpMgmtAgtPath",
                "runElevated": false,
                "inline": [
                        "mkdir c:\\buildActions",
                        "echo Azure-Image-Builder-Was-Here  > c:\\buildActions\\buildActionsOutput.txt"
                    ]
                },
                {
                    "type": "WindowsUpdate",
                    "searchCriteria": "IsInstalled=0",
                    "filters": [
                        "exclude:$_.Title -like '*Preview*'",
                        "include:$true"
                                ],
                    "updateLimit": 20
                }
        ],
        "distribute": 
            [
                {   "type":"ManagedImage",
                    "imageId": "/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>",
                    "location": "<region>",
                    "runOutputName": "<runOutputName>",
                    "artifactTags": {
                        "source": "azVmImageBuilder",
                        "baseosimg": "windows2019"
                    }
                }
            ]
        }
}

```
The example is quite good in general, but the thing, which may not always work, is the idea behind customizing it. The documentation states, what you can use `sed` to replace placeholder in the template file as the first step:
```
curl https://raw.githubusercontent.com/azure/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json -o helloImageTemplateWin.json

sed -i -e "s%<subscriptionID>%$subscriptionID%g" helloImageTemplateWin.json
sed -i -e "s%<rgName>%$imageResourceGroup%g" helloImageTemplateWin.json
sed -i -e "s%<region>%$location%g" helloImageTemplateWin.json
sed -i -e "s%<imageName>%$imageName%g" helloImageTemplateWin.json
sed -i -e "s%<runOutputName>%$runOutputName%g" helloImageTemplateWin.json
sed -i -e "s%<imgBuilderId>%$imgBuilderId%g" helloImageTemplateWin.json
```
The second step is to deploy modified template with `az resource create` (or its counterpart from Azure PowerShell):
```
az resource create \
  --resource-group $imageResourceGroup \
  --properties @helloImageTemplateWin.json \
  --is-full-object \
  --resource-type Microsoft.VirtualMachineImages/imageTemplates \
  -n helloImageTemplateWin01
```
This will work, but to me it's just too imperative and too clumsy. I much prefer a declarative approach with ARM Templates or Bicep, hence let's try to translate the example to something much more useful.

### Writing a template
In order to make deployments of image templates, used by Azure VM Image Builder, much more flexible, we can create a template using ARM Templates or Bicep. An example template could look like this:
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
      offer: 'UbuntuServer'
      sku: '22.04-LTS'
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
The above template will work just fine, allowing you to deploy an image template with quite a few customization options. The important thing here however is the following section:
```
identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
}
```
It defines a [user-assigned identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview), which will be used by Azure VM Image Builder to perform necessary operations within configured scope (building an image and presenting as Azure artifact). Even though that section is pretty simple, you could quite easily make a mistake there, which will render the whole template invalid without telling you, where exactly the problem occurs. 

## Making a mistake
Let's pretend, that we made a mistake and instead of providing such identity configuration in Bicep:
```
identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
}
```
We forgot about specifying the **type** property:
```
identity: {
    userAssignedIdentities: {
      '${uai.id}': {}
    }
}
```
Now, creating a deployment using e.g. Azure CLI will end up with the following error:
```
{
    "code": "InvalidTemplate", 
    "message": "Deployment template parse failed: 'Required property 'type' not found in JSON. Path '', line 43, position 19.'."
}
```
The problem is, that the error itself is quite vague - it doesn't tell us which resource is actually invalid. Instead, it provides some information about location of invalid object, but as we're using Azure Bicep, this information is still useless. Additional challenge when debugging such error is the fact, that it happens _before_ deployment is created. This simply means, that we cannot easily check the generated JSON and need to build it manually.

## Building ARM template from Bicep file
Bicep CLI comes with some additional and useful feature. One of those is Bicep to ARM Template transpilation, which can be performed using the following command:
```
az bicep build --file <file-path> // Azure CLI
bicep build --file <file-path> // Bicep CLI
```
When one of those commands completes, it'll create a generated ARM Template based on your Bicep file. Once you access it, you'll notice, that the line number reported in the error message, may be actually useful:
![transpiled_bicep_file](/images/1_1.PNG)
This wasn't so bad! One additional step and we're already able to spot an error. However, what will happen if we complicate our deployment by using another scope?

## Deploying on a subscription level
With Azure Resource Manager you have a couple of different deployment scopes at your service. In the previous section we used a default scope (resource group), which is a quite common scenario used in both small and big projects. Changing the scope affects both the way how we write code for infrastructure and how deployments are performed technically. If we decide, that we deploy our code on e.g. a subscription level, we need to redesign it:
```
targetScope = 'subscription'

param parLocation string = 'westeurope'
param parName string
param parIdentityName string
param parLocationSuffix string = 'we'
param parImageName string
param parCustomizers array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'blog-rg'
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
  }
}
```
Now, assuming that we still have the same mistake as we had previously:
```
identity: {
    // Missing property 'type'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
}
```
The error will be quite different:
```
{
    "code": "InvalidTemplate", 
    "target": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Resources/deployments/it", 
    "message": "Deployment template parse failed: 'Required property 'type' not found in JSON. Path '', line 1, position 1524.'."
}
```
This time the error returned points to the very first line of underlying JSON object, so we're unable to find the exact spot where it happened. Transpiling Bicep file also won't help here because we don't have a line number to refer to. Even removing whitespaces from the generated JSON isn't helpful - it's actually impossible to tell where exactly the error occurs.

### arm-ttk for the rescue?
To somehow mitigate the problem of incorrectly reporting an error in the template I tried to validate it using [arm-ttk](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/test-toolkit). Unfortunately test results still inform us, that the template is correct:
```
[+] JSONFiles Should Be Valid 
[+] Min And Max Value Are Numbers (41 ms)
Outputs Must Not Contain Secrets
[+] Outputs Must Not Contain Secrets (45 ms)
Parameter Types Should Be Consistent
[+] Parameter Types Should Be Consistent (158 ms)
Parameters Must Be Referenced
[+] Parameters Must Be Referenced (87 ms)
Password params must be secure
[+] Password params must be secure (58 ms)
providers apiVersions Is Not Permitted
[+] providers apiVersions Is Not Permitted (52 ms)
ResourceIds should not contain
[+] ResourceIds should not contain (37 ms)
Resources Should Have Location
[+] Resources Should Have Location (56 ms)
Resources Should Not Be Ambiguous
[+] Resources Should Not Be Ambiguous (39 ms)
Secure Params In Nested Deployments
[+] Secure Params In Nested Deployments (63 ms)
Secure String Parameters Cannot Have Default
[+] Secure String Parameters Cannot Have Default (42 ms)
Template Should Not Contain Blanks
[+] Template Should Not Contain Blanks (114 ms)
URIs Should Be Properly Constructed
[+] URIs Should Be Properly Constructed (68 ms)
Variables Must Be Referenced
[+] Variables Must Be Referenced (43 ms)
Virtual Machines Should Not Be Preview
[+] Virtual Machines Should Not Be Preview (64 ms)
VM Images Should Use Latest Version
[+] VM Images Should Use Latest Version (40 ms)
VM Size Should Be A Parameter
[+] VM Size Should Be A Parameter (62 ms)

Pass  : 31
Fail  : 0
Total : 31
```

## Conclusion
Even though using Infrastructure-as-Code approach in Azure became significantly easier (thanks to toolset offered by Bicep, Terraform and other solutions), Azure Resource Manager can still be a huge PITA, especially in more complicated scenarios. Lack of transparent, stable and simple validation layer causes lots of confusion, even for veteran Azure users, who's deployed thousands of templates. Personally I believe, that the best thing we can do is to work on better syntax validation, which can catch most of the errors, which may happen. In big-scale scenarios, companies will most likely benefit from the private module repositories, which often contain battle-tested and verified components, which can be used out-of-the-box. 

To actually do something in the end instead of just whining - I created an issue in [Bicep types](https://github.com/Azure/bicep-types-az/issues/2007) repository :)