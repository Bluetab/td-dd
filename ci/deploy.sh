#!/bin/bash

service postgresql start

useradd -m deliver
echo "deliver:password" | chpasswd
chsh -s /bin/bash deliver

# apt install locales -y
export LANG=en_US.UTF-8 && echo $LANG UTF-8 > /etc/locale.gen && locale-gen && update-locale LANG=$LANG

cp -R /code /working_code

wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm
yum install git -y
yum install openssh-server openssh-clients -y
cat /etc/ssh/sshd_config | sed "s/PasswordAuthentication no/PasswordAuthentication yes/g" > /etc/ssh/sshd_config
chkconfig sshd on
service sshd start

chmod -R 777 /working_code
chgrp -R deliver /working_code

echo "
export PRODUCTION_HOST=$PRODUCTION_HOST
export PRODUCTION_USER=$PRODUCTION_USER
export TARGET_MIX_ENV=$TARGET_MIX_ENV
export DB_PASSWORD=$DB_PASSWORD
export DB_HOST=$DB_HOST
export TERM=$TERM
export PRODUCTION_PEM=\"$PRODUCTION_PEM\"" >> /working_code/env_vars.sh

chmod +x /working_code/env_vars.sh

su deliver -c '/working_code/ci/deploy_as_deliver.sh'
