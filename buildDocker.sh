#!/usr/bin/env bash

export PROJECT_NAME=td_dq

docker build --build-arg APP_VERSION=$(cat version) --build-arg APP_NAME=$PROJECT_NAME --build-arg MIX_ENV=prod -t bluetab-truedat/$PROJECT_NAME:latest .
docker rmi --force $(docker images -f "dangling=true" -q)
