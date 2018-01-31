#!/bin/bash
sed -i -e "s/username:.*,/username: \"$DB_USER\",/g" ./config/prod.secret.exs
sed -i -e "s/password:.*,/password: \"$DB_PASSWORD\",/g" ./config/prod.secret.exs
sed -i -e "s/database:.*,/database: \"$DB_NAME\",/g" ./config/prod.secret.exs
sed -i -e "s/hostname:.*,/hostname: \"$DB_HOST\",/g" ./config/prod.secret.exs
cp ./config/prod.secret.exs ~/truebg.prod.secret.exs
