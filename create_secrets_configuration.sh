#!/bin/bash
sed -i -e "s/username:.*,/username: \"$DB_USER\",/g" ./config/prod.secret.exs
sed -i -e "s/password:.*,/password: \"$DB_PASSWORD\",/g" ./config/prod.secret.exs
sed -i -e "s/database:.*,/database: \"$DB_NAME\",/g" ./config/prod.secret.exs
sed -i -e "s/hostname:.*,/hostname: \"$DB_HOST\",/g" ./config/prod.secret.exs
sed -i -e "s/secret_key:.*/secret_key: \"$GUARDIAN_SECRET_KEY\"/g" ./config/prod.secret.exs
cp ./config/prod.secret.exs ~/td_dq.prod.secret.exs
