#!/bin/sh
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile
