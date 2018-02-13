#!/bin/bash

service postgresql96 start

cp -R /code /working_code
cd /working_code

echo "Starting build step"

echo "Starting prebuild configuration"
mix local.hex --force
echo "local hex executed"
mix local.rebar --force
mix deps.clean --all
echo "local rebar executed"
echo "Starting clean installed dependencies"
mix deps.clean --all || exit 1
echo "Dependencies cleaned, Starting get dependencies and compile project"
mix do deps.get, compile || exit 1

echo "Build step finish successfully"
