---
title: "Handling dynamic retail prices of Azure services in Azure Cost Estimator"
slug: handling-dynamic-retail-prices-in-ace
summary: 'Developing ACE has become more and more cumbersome due to instability of tests verifying if estimations are correct. That instability was caused by dynamic prices returned by Azure Retails API, what caused the tests to fail randomly. As it affected more and more test cases, I decided to rework the way how test work. Let us discuss it.'
date: 2024-01-06T15:29:10+01:00
type: posts
draft: false
categories:
- Azure
- Programming
- Dotnet
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
After giving myself a break and charging my mind's batteries, I decided to return to development of Azure Cost Estimator. However, I've been also aware, that there's one area in the project, which requires some serious redesigning. That area was tests, which verified how each cost estimation work. This was a serious problem - without correctly working tests, I'm unable to secure the project from all kind of errors and bugs, which may happen during development of new features. 

Before we deep dive into actual solution, let's talk for a moment about root cause of failing tests.

## Idea for tests in Azure Cost Estimator
Azure Cost Estimator bases its estimations on two main components:
* prices of Azure services
* estimations logic implemented for each service inside the library

The prices are fetched from [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices) during each run. This has its pros and const - while it gives you confidence, that any price change presented by Microsoft won't go unnoticed, it also seriously impacts the ability to introduce a stable test suite (as almost all tests in ACE are E2E tests). 

Instability of prices isn't the same for each service - while services like Azure Container Registry, Azure Storage or Azure Event Hub have quite a constant pricing, Azure Virtual Machines have not. The same was happening for a subset of metrics for Azure Monitor - a price could change each day, what caused the whole test suite to fail. Such behaviour impacted my ability to validate logic of the whole Azure Cost Estimator and, ultimately, was rather discouraging. Quite recently I decided, that this needs to stop and started looking for a solution.

## Mocking Retail API responses
Initially, I was thinking about switching from E2E tests to some other types of tests, which can run in total isolation. Yes, it'd probably solve most of the problems, but I still wanted to be able to test the whole workflow - from entering options for a command to returning results. Such approach has a number of benefits:
* I'm confident, that given set of options and parameters returns expected result
* I don't need to expose internal or private members of the library to the test suite
* I don't need to rewrite all the tests from scratch

This is why I decided to go for an alternative solution - being able to seed a test with a mocked (or pre-generated) Retail API response. This is how it was done for ACE.

### Introducing new option
To be able to pass Retail API response to a test, I decided, that ACE will gain new option:
```
var retailAPIResponsePathOption = new Option<FileInfo?>("--mocked-retail-api-response-path", "Path to a file containing mocked Retail API response. Used for testing purposes only.");
```
This option allows me to pass a file containing static Retail API response as input for an estimation like so:
```
[Test]
public async Task AKS_DiskCalculation_WhenTemplateDefinesUltraSSDDisk_ItShouldBeCalculatedCorrectly()
{
    var outputFilename = $"ace_test_{DateTime.Now.Ticks}";
    var exitCode = await Program.Main(new[] {
            "templates/reworked/aks/ultrassd.bicep",
            "cf70b558-b930-45e4-9048-ebcefb926adf",
            "arm-estimator-tests-rg",
            "--generateJsonOutput",
            "--jsonOutputFilename",
            outputFilename,
            "--mocked-retail-api-response-path",
            "mocked-responses/retail-api/aks/ultrassd.json"
        });

    Assert.That(exitCode, Is.EqualTo(0));

    var outputFile = File.ReadAllText($"{outputFilename}.json");
    var output = JsonSerializer.Deserialize<EstimationOutput>(outputFile, new JsonSerializerOptions()
    {
        PropertyNameCaseInsensitive = true
    });

    Assert.That(output, Is.Not.Null);
    Assert.Multiple(() =>
    {
        Assert.That(output.TotalCost.OriginalValue, Is.EqualTo(162.22352000000001d));
        Assert.That(output.TotalResourceCount, Is.EqualTo(1));
    });

}
```
The pre-generated response from Retail API was easy to obtain as ACE automatically builds a filter, which is used when calling the API:
```
https://prices.azure.com/api/retail/prices?currencyCode='USD'&$filter=priceType eq 'Consumption' and (((serviceId eq 'DZH313Z7MMC8' and armRegionName eq 'westeurope' and skuName eq 'D2s v3' and productName eq 'Virtual Machines DSv3 Series Windows') or (serviceId eq 'DZH317F1HKN0' and armRegionName eq 'westeurope' and skuName eq 'Ultra LRS')))
```
Such response will look like this - it can be saved as JSON file and then used as input:
```
{
    "BillingCurrency": "USD",
    "CustomerEntityId": "Default",
    "CustomerEntityType": "Retail",
    "Items": [
      {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "retailPrice": 8.8E-05,
        "unitPrice": 8.8E-05,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2019-10-30T00:00:00Z",
        "meterId": "13c698e9-e26c-4d9c-94b4-f668f8bc6deb",
        "meterName": "Ultra LRS Provisioned IOPS",
        "productId": "DZH318Z0BP68",
        "skuId": "DZH318Z0BP68/0006",
        "productName": "Ultra Disks",
        "skuName": "Ultra LRS",
        "serviceName": "Storage",
        "serviceId": "DZH317F1HKN0",
        "serviceFamily": "Storage",
        "unitOfMeasure": "1/Hour",
        "type": "Consumption",
        "isPrimaryMeterRegion": true,
        "armSkuName": ""
      },
      {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "retailPrice": 0.000213,
        "unitPrice": 0.000213,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2019-10-30T00:00:00Z",
        "meterId": "38394a77-2cd5-4ed7-8cfc-778297962ed8",
        "meterName": "Ultra LRS Provisioned Capacity",
        "productId": "DZH318Z0BP68",
        "skuId": "DZH318Z0BP68/0006",
        "productName": "Ultra Disks",
        "skuName": "Ultra LRS",
        "serviceName": "Storage",
        "serviceId": "DZH317F1HKN0",
        "serviceFamily": "Storage",
        "unitOfMeasure": "1 GiB/Hour",
        "type": "Consumption",
        "isPrimaryMeterRegion": true,
        "armSkuName": ""
      },
      {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "retailPrice": 0.0078,
        "unitPrice": 0.0078,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2019-10-30T00:00:00Z",
        "meterId": "40a54ded-7840-4be0-a0dc-d034d3e78d0b",
        "meterName": "Ultra LRS Reservation per vCPU Provisioned",
        "productId": "DZH318Z0BP68",
        "skuId": "DZH318Z0BP68/0006",
        "productName": "Ultra Disks",
        "skuName": "Ultra LRS",
        "serviceName": "Storage",
        "serviceId": "DZH317F1HKN0",
        "serviceFamily": "Storage",
        "unitOfMeasure": "1/Hour",
        "type": "Consumption",
        "isPrimaryMeterRegion": true,
        "armSkuName": ""
      },
      {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "retailPrice": 0.212,
        "unitPrice": 0.212,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2017-06-17T00:00:00Z",
        "meterId": "bb009211-3bf3-4734-a7e2-52cb394d2b0f",
        "meterName": "D2s v3",
        "productId": "DZH318Z0BPWD",
        "skuId": "DZH318Z0BPWD/00G4",
        "productName": "Virtual Machines DSv3 Series Windows",
        "skuName": "D2s v3",
        "serviceName": "Virtual Machines",
        "serviceId": "DZH313Z7MMC8",
        "serviceFamily": "Compute",
        "unitOfMeasure": "1 Hour",
        "type": "Consumption",
        "isPrimaryMeterRegion": false,
        "armSkuName": "Standard_D2s_v3"
      },
      {
        "currencyCode": "USD",
        "tierMinimumUnits": 0.0,
        "retailPrice": 0.000572,
        "unitPrice": 0.000572,
        "armRegionName": "westeurope",
        "location": "EU West",
        "effectiveStartDate": "2021-05-01T00:00:00Z",
        "meterId": "b2ab2927-4439-4afb-be02-dd96224acf14",
        "meterName": "Ultra LRS Provisioned Throughput (MBps)",
        "productId": "DZH318Z0BP68",
        "skuId": "DZH318Z0BP68/0006",
        "productName": "Ultra Disks",
        "skuName": "Ultra LRS",
        "serviceName": "Storage",
        "serviceId": "DZH317F1HKN0",
        "serviceFamily": "Storage",
        "unitOfMeasure": "1/Hour",
        "type": "Consumption",
        "isPrimaryMeterRegion": true,
        "armSkuName": ""
      }
    ],
    "NextPageLink": null,
    "Count": 5
  }
```
In the end, the last thing needed was intercepting that mocked response in `WhatIfProcessor` responsible for handling What If responses and interacting with Retail API:
```
private async Task<RetailAPIResponse?> GetRetailAPIResponse<T>(WhatIfChange change,
                                                               CommonResourceIdentifier id,
                                                               CancellationToken token) where T : BaseRetailQuery, IRetailQuery
{
    if (token.IsCancellationRequested)
    {
        return null;
    }

    bool ShouldTakeMockedData() 
    {
        return this.mockedRetailAPIResponsePath != null && this.mockedRetailAPIResponsePath.Exists;
    }

    if (ShouldTakeMockedData())
    {
        this.logger.LogWarning("Using mocked data for {type}.", typeof(T));
        var mockedData = await File.ReadAllTextAsync(this.mockedRetailAPIResponsePath!.FullName, token);
        return JsonSerializer.Deserialize<RetailAPIResponse>(mockedData);
    }

    ...
}
```
From now on, I'm able to secure each test from changes to the prices returned by Azure Retail Price API. You may wonder if mocking a response from that API isn't taking away the ability of react to changes, which would affect cost estimation. From my perspective it seems, that even if a price is changed, it has less probability to introduce an error to an estimation when compared to instable test, which tends to be ignored. However, the mocked response introduced another problem, which I needed to handle.

## Generating proper query filter in mocked test
Once I started using mocked responses, I realized, that that's not over yet. The problem introduced by a mocked response is trivial - if response is mocked, it doesn't matter what template is used. This means, that a test uses Retail API response, which may not be related with a template provided. To make sure, that test cases is properly tested, I still should interact with Retail API - this time however only to generate meters used in cost calculation. The alternative is to let ACE to build the filter used in Retail API query and confirming, that it reflects the filter used to generated response. After some condsideration, I decided to go with the latter:
```
bool ShouldTakeMockedData()
{
    return this.mockedRetailAPIResponsePath != null && this.mockedRetailAPIResponsePath.Exists;
}

if (ShouldTakeMockedData())
{
    this.logger.LogWarning("Using mocked data for {type}.", typeof(T));
    var mockedData = await File.ReadAllTextAsync(this.mockedRetailAPIResponsePath!.FullName, token);
    var response = JsonSerializer.Deserialize<RetailAPIResponse>(mockedData);

    if(response == null || response.Url != url) {
        logger.LogError("Mocked data URL doesn't match the URL generated by the application.");
        return null;
    }

    return response;
}
```
This ensures me, that Retail API query is properly generated and handled - if ACE generates different filter, it cannot be used for that test due to data differences.

## Summary
I'm happy with the whole test redesigning tasks, as it allowed me to review existing test cases and introduce proper path for the upcoming `1.4` release of Azure Cost Estimator. There's still lots of things to do (most of the tests need to be ported to a new approach), but the whole change should bring higher quality in overall and let manage test suites in more controlled manner.