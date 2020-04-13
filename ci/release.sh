#!/bin/sh
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

mix release
find . -name "*.tar.gz"
