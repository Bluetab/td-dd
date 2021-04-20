#!/bin/sh

set -o errexit
set -o xtrace

bin/td_dd eval 'Elixir.TdDq.Release.migrate()'
bin/td_dd start
