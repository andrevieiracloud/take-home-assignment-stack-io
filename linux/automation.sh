#!/bin/bash

# Variables for control
DOCKERFILE_PATH="../dockerize/Dockerfile"
IMAGE_NAME="my-go-webserver"
TAG=$(date +"%Y%m%d%H%M%S") # Defining Current TAG
NEW_IMAGE="${IMAGE_NAME}:${TAG}"
SCRIPT_YAML="./script.yaml"
NEW_APP_YAML="./new-app.yaml"

echo "Building Docker image..."
cd ../dockerize
docker build -t $NEW_IMAGE -f $DOCKERFILE_PATH .
cd ../linux

echo "Creating new-app.yaml..."
sed "s|MY_NEW_IMAGE|$NEW_IMAGE|g" $SCRIPT_YAML > $NEW_APP_YAML

echo "Diff for Comparing current state in minikube with new-app.yaml..."
kubectl diff -f $NEW_APP_YAML
