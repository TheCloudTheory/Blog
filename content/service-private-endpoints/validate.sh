#!/bin/bash

sas1=`az storage blob generate-sas -c test -n deployment.bicep --permissions r --account-name sapublicne --expiry 2024-01-31T00:00:00Z | jq -r .`
sas2=`az storage blob generate-sas -c test -n deployment.bicep --permissions r --account-name sasene --expiry 2024-01-31T00:00:00Z | jq -r .`
sas3=`az storage blob generate-sas -c test -n deployment.bicep --permissions r --account-name sapene --expiry 2024-01-31T00:00:00Z | jq -r .`

curl "https://sapublicne.blob.core.windows.net/test/deployment.bicep?$sas1"
curl "https://sasene.blob.core.windows.net/test/deployment.bicep?$sas2"
curl "https://sapene.blob.core.windows.net/test/deployment.bicep?$sas3"