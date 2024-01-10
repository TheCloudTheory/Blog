---
title: "Azure DevOps, Bash nad parameters confusion"
slug: azure-devops-bash-parameters-confusion
summary: 'In tools such as Azure DevOps you often need to execute your custom script and pass parameters to it. Things get tricky when your parameters contain special characters, which get handles in surprising way. In this article, I am going to cover simple, yet nasty example, where script just does not work, and there is nothing, which gives a warning.'
date: 2024-01-09T16:39:27+01:00
type: posts
draft: false
categories:
- AzureDevOps
- Bash
tags:
- azure
- devops
- bash
- script
- parameters
series:
- CICD
---
Using custom scripts in CICD pipelines is often a must. It's difficult to provide everything as set of inline commands, especially in more sophisticated scenarios involving customization, parsing and validation. Things get even more complicated, when you need to provide parameters, which contain special characters. As presented in this blog post, tools like Azure DevOps will happily process your script, even if they were unable to pass parameters correctly. Let's get started.

## Writing a script
As an example, we'll use the following script:
```
#!/bin/bash

if [ $# -ne 6 ]; then
    echo "Usage: $0 <resource-group> <location> <storage-account> <container> <file-content> <blob-name>"
    exit 1
fi

if [ -z $1 ]; then
    echo "Resource group name is empty!"
    exit 1
fi

if [ -z $2 ]; then
    echo "Location is empty!"
    exit 1
fi

if [ -z $3 ]; then
    echo "Storage account name is empty!"
    exit 1
fi

if [ -z $4 ]; then
    echo "Container name is empty!"
    exit 1
fi

if [ -z $5 ]; then
    echo "File content!"
    exit 1
fi

if [ -z $6 ]; then
    echo "Blob name is empty!"
    exit 1
fi

if [ ! -f "./file.txt" ]; then
    echo "$5" > file.txt
fi


az group create -n $1 -l $2
az storage account create -n $3 -g $1 -l $2 --sku Standard_LRS
az storage container create -n $4 --account-name $3
az storage blob upload -f "./file.txt" -c $4 -n $6 --account-name $3
```
It's simple as that. Long story short - it will create a resource group, storage account and upload a blob based on the provided content. Nothing fancy, we'll also skip extra logic responsible for checking for duplicates etc. to focus on what's important. Using such script, we could run it as so:
```
./script.sh blog-rg westeurope sablogwe files file.dat "sp=r&st=2024-01-09T15:55:32Z&se=2024-01-09T23:55:32Z&spr=https&sv=2022-11-02"
```
As you can see, when executing the script, we're passing a bunch of input parameters, one of them being part of a SAS token generated for a different file (it doesn't actually matter, that it's such a specific value - what's important, is that it contains special characters). The result of running the script would be a new resource group with storage account, container and blob uploaded. Great - let's try to run it in a more controller (and non-interactive) way.

## Running the script in Azure DevOps
Let's create a simple YAML pipeline, which could leverage our script:
```
trigger: none

pool:
  vmImage: ubuntu-latest

parameters:
  - name: resourceGroupName
    displayName: 'Resource group name'
    default: 'blog-rg'
  - name: location
    displayName: 'Location'
    default: 'westeurope'
  - name: storageAccountName
    displayName: 'Storage account name'
    default: 'sablogwe'
  - name: storageAccountContainerName
    displayName: 'Container name'
    default: 'files'
  - name: fileContent
    displayName: 'File content'
  - name: blobName
    displayName: 'Blob name'
    default: 'file.dat'

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Blog'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      chmod +x ./script.sh
      ./script.sh ${{ parameters.resourceGroupName }} ${{ parameters.location }} ${{ parameters.storageAccountName }} ${{ parameters.storageAccountContainerName }} ${{ parameters.fileContent }} ${{ parameters.blobName }}
```
Thanks to parameters, the only value, which we need to pass is `fileContent`. However, when we provide the same values as we did for the script run locally, the script won't complete successfully:
```
Usage: ./script.sh <resource-group> <location> <storage-account> <container> <file-content> <blob-name>
/home/vsts/work/_temp/azureclitaskscript1704829831842.sh: line 2: file.dat: command not found
##[error]Script failed with exit code: 127
```
The error above may be actually helpful, as it indicates, that `file.dat` value (being the last parameter) is treated as it'd a command. Something terminates the input, so the whole script execution fails. Now, if we change the order of parameters, the following things happen. In the first step, we'll just reorder the two last parameters (without changing the script):
```
steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Blog'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      chmod +x ./script.sh
      ./script.sh ${{ parameters.resourceGroupName }} ${{ parameters.location }} ${{ parameters.storageAccountName }} ${{ parameters.storageAccountContainerName }}  ${{ parameters.blobName }} ${{ parameters.fileContent }}
```
Then, let's try to run the script. What's surprising, this time it completes successfully. However, closer look at the output reveals, that the only reason it completed, is the lack of failing on stderr:
```
WARNING: 
There are no credentials provided in your command and environment, we will query for account key for your storage account.
It is recommended to provide --connection-string, --account-key or --sas-token in your command as credentials.

You also can add `--auth-mode login` in your command to use Azure Active Directory (Azure AD) for authorization if your login account is assigned required RBAC roles.
For more information about RBAC roles in storage, visit https://docs.microsoft.com/azure/storage/common/storage-auth-aad-rbac-cli.

In addition, setting the corresponding environment variables can avoid inputting credentials in your command. Please use --help to get more information about environment variable usage.
WARNING: 
Skip querying account key due to failure: Please run 'az login' to setup account.
ERROR: Server failed to authenticate the request. Please refer to the information in the www-authenticate header.
RequestId:b9972709-301e-0041-8037-4369ed000000
Time:2024-01-09T20:10:06.9403548Z
ErrorCode:NoAuthenticationInformation
WARNING: 
There are no credentials provided in your command and environment, we will query for account key for your storage account.
It is recommended to provide --connection-string, --account-key or --sas-token in your command as credentials.

You also can add `--auth-mode login` in your command to use Azure Active Directory (Azure AD) for authorization if your login account is assigned required RBAC roles.
For more information about RBAC roles in storage, visit https://docs.microsoft.com/azure/storage/common/storage-auth-aad-rbac-cli.

In addition, setting the corresponding environment variables can avoid inputting credentials in your command. Please use --help to get more information about environment variable usage.
WARNING: 
Skip querying account key due to failure: Please run 'az login' to setup account.
ERROR: Server failed to authenticate the request. Please refer to the information in the www-authenticate header.
RequestId:3068d060-a01e-000e-5037-4318b9000000
Time:2024-01-09T20:10:08.0965011Z
ErrorCode:NoAuthenticationInformation
```
Something isn't right, but we're unable to detect that. The script runs, but Azure CLI is unable to use the credentials, like some part of the script was run outside `Azure CLI` task. Let's take a look.

## Understanding `&` in Bash
To get started, let's run the following commands:
```
echo foo
echo "foo"
```
For both those commands, result will be the same:
```
foo
foo
```
However, if we compare those two commands:
```
echo foo&
echo "foo&"
```
We'll get completely different results:
```
# echo foo&
[1] 406
foo

# echo "foo&"
foo&
[1]+  Done                    echo foo

# running echo "foo&" one more time
foo&
```
Right, something strange is happening to the script execution. It seems, that running `echo foo&` doesn't end the first time it's run - running a command afterwards still obtains the result of the first execution. What's more, the first command doesn't actually return the expected result - it returns `foo` instead of `foo&`. Why is that?

If you're familiar with Unix systems, the answer will be obvious. For people, who are used to working with Windows, the answer may require additional description. In short, when running a script (using e.g. Bash), you may want to instruct a shell to run your script in background. This is exactly what `&` is for - it enables you to start execution of a command or script without waiting for its completion. You can easily check that by using the `sleep` command:
```
sleep 10 &
```
When executed, it'll run in a background waiting for 10 seconds. It won't block you from executing any commands in the foreground and eventually return `Done sleep 10` result. If you wish, you could compare the execution with `sleep 10`, so you can see the difference. Great, we're wiser now. Let's go back to our script in Azure DevOps.

## Fixing the script
If we take a closer look at the values provided to our script, we'll realize, that one of the values passed as a parameter may generate problems:
```
sp=r&st=2024-01-09T15:55:32Z&se=2024-01-09T23:55:32Z&spr=https&sv=2022-11-02
```
A quick test will just confirm what you could suspect:
```
echo sp=r&st=2024-01-09T15:55:32Z&se=2024-01-09T23:55:32Z&spr=https&sv=2022-11-02
[6] 420
sp=r
[7] 421
[8] 422
[9] 423
[6]   Done                    echo sp=r
[7]   Done                    st=2024-01-09T15:55:32Z
[8]-  Done                    se=2024-01-09T23:55:32Z
```
The issue with our value is related to ampersands, which it contains. As we now, each `&` will tell the shell to run the command in the background. If run with `echo` it's easy to catch, however if run with our script, it causes a cascade of failures. Depending on the place, where such value is used, it will either break validation, or derail the whole execution (hence authorization error in Azure DevOps - only part of the script is run in the foreground with properly authenticated account. The rest runs in the background, where it cannot use the authorized execution context). 

Things get especially interesting when you don't control the value directly. If it's just an input (or even worse - a secret), you'll be just making circles trying to find the root cause of a script error. For that, I don't have a solution (well, intuition may help, but that's not something we could buy). Fortunately, we could secure ourselves from such bugs by introducing a simple change to the YAML pipeline:
```
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Blog'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      chmod +x ./script.sh
      ./script.sh "${{ parameters.resourceGroupName }}" "${{ parameters.location }}" "${{ parameters.storageAccountName }}" "${{ parameters.storageAccountContainerName }}" "${{ parameters.blobName }}" "${{ parameters.fileContent }}"
```
Yes! The magic of quotes will help us here. It's that simple - now the script is able to run correctly, even if any of the values provided contain an ampersand.