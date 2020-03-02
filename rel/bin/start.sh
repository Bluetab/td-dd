#!/bin/sh

set -o errexit
set -o xtrace

bin/td_cx eval 'Elixir.TdCx.Release.migrate()'
bin/td_cx start
