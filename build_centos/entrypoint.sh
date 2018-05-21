#!/bin/bash

cp -R /code /working_code
chmod -R 777 /working_code
cd /working_code

echo "Starting deploy"

mix local.rebar --force
rm -rf ./_build
mix deps.clean --all
mix deps.get

. ./build_centos/env.conf
./build_centos/create_secrets_configuration.sh || exit 1

mix phx.digest
MIX_ENV=prod mix release
cp _build/prod/rel/td_dd/releases/0.0.1/td_dd.tar.gz /code/dist/

echo "Finished deployment"
