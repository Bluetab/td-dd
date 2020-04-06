#!/bin/sh

set -o errexit
set -o xtrace

bin/td_dq eval 'Elixir.TdDq.Release.migrate()'
bin/td_dq start
