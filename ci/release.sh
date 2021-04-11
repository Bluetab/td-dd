#!/bin/sh
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

mix release --env=${MIX_ENV:-prod}
find . -name "*.tar.gz"
