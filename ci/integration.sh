#!/bin/bash

function wait_for {
  while ! nc -z $1 $2; do
    echo "$1 is unavailable - sleeping"
    sleep 1
  done
}
#
# mkdir -p /root/.ssh/
# ssh-keyscan gitlab.bluetab.net >> /root/.ssh/known_hosts
# cp /data/ssh/* /root/.ssh/

service postgresql96 start

# git clone git@gitlab.bluetab.net:dgs-core/true-dat/back-end/td-auth.git /td_auth
# #git clone git@gitlab.bluetab.net:dgs-core/true-dat/back-end/td-bg.git /td_bg
# #git clone git@gitlab.bluetab.net:dgs-core/true-dat/back-end/td-dl.git /td_dl
# #git clone git@gitlab.bluetab.net:dgs-core/true-dat/back-end/td-dq.git /td_dq
# git clone git@gitlab.bluetab.net:dgs-core/true-dat/back-end/td-dd.git /td_dd
# git clone git@gitlab.bluetab.net:dgs-core/true-dat/td-int.git /td_int

cd /td_auth
mix local.rebar --force
mix deps.clean --all
mix deps.get

if [ -d "assets" ]; then
  cd assets
  yarn install
  cd ..
fi

mix ecto.create && mix ecto.migrate
nohup mix phx.server &

cd /td_bg
mix local.rebar --force
mix deps.clean --all
mix deps.get

if [ -d "assets" ]; then
  cd assets
  yarn install
  cd ..
fi

mix ecto.create && mix ecto.migrate
nohup mix phx.server &

cd /td_dd
mix local.rebar --force
mix deps.clean --all
mix deps.get

if [ -d "assets" ]; then
  cd assets
  yarn install
  cd ..
fi

mix ecto.create && mix ecto.migrate
nohup mix phx.server &

yum install nc -y
yum install python36-virtualenv -y

virtualenv-3.6 venv
. ./venv/bin/activate
pip3.6 install -r requirements.txt

wait_for localhost 4001
#wait_for td_bg   4002
#wait_for td_dl   4003
#wait_for td_dq   4004
wait_for localhost 4005

cd /td_int/tests && chmod +x run_tests.sh && ./run_tests.sh
