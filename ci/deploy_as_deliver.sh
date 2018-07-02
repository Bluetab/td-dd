#!/bin/bash

cd /working_code
/working_code/env_vars.sh

echo "distro requirements"

mkdir -p ~/.ssh
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""
chmod 600 ~/.ssh/id_rsa*
sshpass -p "password" ssh-copy-id -o StrictHostKeyChecking=no deliver@localhost || exit 1

echo "Starting deploy"

MIX_ENV=prod

mix local.hex --force
mix local.rebar --force
rm -rf ./_build
mix deps.clean --all
mix deps.get
MIX_ENV=prod mix phx.swagger.generate priv/static/swagger.json

./create_secrets_configuration.sh || exit 1

mix edeliver build release --revision=$CI_BUILD_REF --auto-version=git-revision || exit 1

./add_deployment_keys.sh || exit 1

mix edeliver deploy release to production || exit 1

mix edeliver restart production || exit 1

./cleanup_build.sh || exit 1

echo "Finished deployment"
