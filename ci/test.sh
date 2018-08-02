#!/bin/bash

service postgresql96 start
redis-server --daemonize yes --protected-mode no

cp -R /code /working_code
cd /working_code

echo "Starting test step"

export MIX_ENV=test

echo "Starting prebuild configuration"
mix local.hex --force
echo "local hex executed"
mix local.rebar --force
mix deps.clean --all
echo "local rebar executed"
echo "Downloading deps"
mix deps.get
mix phx.swagger.generate priv/static/swagger.json
echo "Executing credo"
mix credo --strict || exit 1
echo "Starting tests"
mix test || exit 1

echo "Test step finish successfully"
