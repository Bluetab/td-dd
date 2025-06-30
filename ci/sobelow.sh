#!/bin/sh
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

mix local.hex --force
mix local.rebar --force
mix sobelow --private --compact --ignore Config.Secrets,Config.HTTPS --router lib/td_cx_web/router.ex
mix sobelow --private --compact --ignore Config.Secrets,Config.HTTPS --router lib/td_dd_web/router.ex
mix sobelow --private --compact --ignore Config.Secrets,Config.HTTPS --router lib/td_dq_web/router.ex