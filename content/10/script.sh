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