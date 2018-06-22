#!/usr/bin/env bash

docker build --build-arg APP_VERSION=$(cat version) --build-arg APP_NAME=td_dq --build-arg MIX_ENV=prod -t bluetab-truedat/td-dq:latest .
docker rmi --force $(docker images -f "dangling=true" -q)
