#!/bin/bash

service postgresql96 start

useradd -m deliver
echo "deliver:password" | chpasswd
chsh -s /bin/bash deliver

# apt install locales -y
localedef -c -f UTF-8 -i en_US en_US.UTF-8
export LC_ALL=en_US.UTF-8

service sshd start

cp -R /code /working_code
chmod -R 777 /working_code
chgrp -R deliver /working_code

echo "
export PRODUCTION_HOST=$PRODUCTION_HOST
export PRODUCTION_USER=$PRODUCTION_USER
export TARGET_MIX_ENV=$TARGET_MIX_ENV
export DB_PASSWORD=$DB_PASSWORD
export DB_HOST=$DB_HOST
export TERM=$TERM
export GUARDIAN_SECRET_KEY=$GUARDIAN_SECRET_KEY
export PRODUCTION_PEM=\"$PRODUCTION_PEM\"" >> /working_code/env_vars.sh

chmod +x /working_code/env_vars.sh

su deliver -c '/working_code/ci/deploy_as_deliver.sh'
