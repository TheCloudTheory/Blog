---
title: "Developing GitHub Action for Azure Cost Estimator"
slug: developing-github-action-for-ace
summary: 'When using Azure Cost Estimator in GitHub Actions, it may be a little bit tricky to properly configure it, so you can benefit from capabilities. As it was already requested, I decided to develop my own GitHub Action, which can be used as a simplified interface for the tool. This is a short introduction to the topic and development path of the project.'
date: 2024-01-04T21:12:02+01:00
type: posts
draft: false
categories:
- Programming
- Azure
- JavaScript
tags:
- azure
- cost
- estimator
- github
- actions
- finops
- automation
series:
- ACE
---
When I started working on Azure Cost Estimator (ACE), I already knew, that at some point people may starting asking about a simpler way to run the tool. What's more, it also turned out, that there're some scenarios, in which limitation of GitHub Actions will introduce serious issues to properly ACE. This is when the whole initiative to create a custom GitHub Action started. In this blog post, I'll try to show you how such action is developed and how you could use it.
> If you're unfamiliar with Azure Cost Estimator, take a look at the [project's](https://github.com/TheCloudTheory/arm-estimator) GitHub repository.

Let's get started.

## Why GitHub Action?
To understand why GitHub Actions seems like a logical choice for using Azure Cost Estimator in a workflow, you need to understand limitations, which are introduced by GitHub. Let's consider standard way of using the tool in your workflow:
1. Download binaries / Pull Docker image
2. Make sure ACE has access to the template file you selected
3. Run the estimation

This is (or was) the easiest way to run ACE, which gives you full control over both inputs and outputs of the estimation. On the other hand, it's also the most "primitive" way of running it - it requires you to cope with ACE version, proper use of options and understanding overall syntax of exposed commands. To address that, I received a tremendous help from [Gordon Byers](https://github.com/Gordonby), who introduced a **Reusable Workflow** - a feature in GitHub Actions, which allows you to run a workflow stored in another repository. It worked (and still works!) great, but has some serious limitations to the files, which are passed as input for a workflow.

As described in [this](https://github.com/TheCloudTheory/arm-estimator/issues/223) issue, to be able to pass a file to a workflow, which is inside a private repository, you need to craft a personal access token and pass it along a file. While doable, it far from optimal solution and I felt, that it may feel rather clumsy to go that way. That's when custom GitHub Action started to look realy tasty.

## Developing GitHub Action for ACE
It turned out, that development of such action isn't difficult - for the initial versions I decided to go for a JavaScript action, as it looked as the simplest and the most robust way of having a working example. Here's a snippet from the implementation:
```
const core = require('@actions/core');
const github = require('@actions/github');
const execSync = require('child_process').execSync;

try {
    console.log('Downloading Azure Cost Estimator.')
    execSync('wget https://github.com/TheCloudTheory/arm-estimator/releases/download/1.3/linux-x64.zip');
    execSync('unzip -o linux-x64.zip');
    execSync('chmod +x ./azure-cost-estimator');

    console.log('Running Azure Cost Estimator.')
    let command = './azure-cost-estimator';

    if(core.getInput('resource-group-name') && core.getInput('subscription-id')) {
        command += ' ' + core.getInput('template-file') + ' ' + core.getInput('subscription-id') + ' ' + core.getInput('resource-group-name');
    }
    else if(core.getInput('subscription-id') && core.getInput('resource-group-name') == null && core.getInput('location')) {
        command += ' sub ' + core.getInput('template-file') + ' ' + core.getInput('subscription-id') + ' ' + core.getInput('location');
    }
    else if(core.getInput('management-group-id')) {
        command += ' mg ' + core.getInput('template-file') + ' ' + core.getInput('management-group-id');
    }
    else if(core.getInput('tenant-id')) {
        command += ' tenant ' + core.getInput('tenant-id') + ' ' + core.getInput('template-file');
    }
    else {
        throw new Error('Please provide a valid input.');
    }
    
    ...
    const result = execSync(command).toString();
    console.log(result);
} catch (error) {
    core.setFailed(error.message);
}
```
In short, it performs most of the heavy lifting itself instead of offloading it to a user:
* it downloads ACE binaries and unpacks them
* it selects a correct combination of commands depending on the input provided
* it reports results to the console

> Note, that as for now, GitHub Action for Azure Cost Estimator is limited to Linux agents only.

Yeah, it doesn't look like an ambitious project. However, here, the key is simplicity - if I'm able to lower the entry level for the project, it may be easier to adapt it to a higher number of workflows and applications.

## Usage
GitHub Action for Azure Cost Estimator is already available on [marketplace](https://github.com/marketplace/actions/azure-cost-estimator-github-action) as preview. Feel free to give it a try if you're interested and share your feedback :)