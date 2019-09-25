#!/bin/bash

ACR_NAME=acrazuretest08
echo "Build image:"
az acr build --registry $ACR_NAME --image baseimages/node:9-alpine --file Dockerfile-base .
