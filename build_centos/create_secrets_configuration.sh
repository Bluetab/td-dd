#!/bin/bash
sed -i -e "s/username:.*,/username: \"$DB_USER\",/g" ./config/prod.secret.exs
sed -i -e "s/password:.*,/password: \"$DB_PASSWORD\",/g" ./config/prod.secret.exs
sed -i -e "s/database:.*,/database: \"$DB_NAME\",/g" ./config/prod.secret.exs
sed -i -e "s@secret_key:.*@secret_key: \"$GUARDIAN_SECRET_KEY\"@g" ./config/prod.secret.exs
sed -i -e "s/auth_host:.*,/auth_host: \"$API_AUTH_HOST\",/g" ./config/prod.secret.exs
sed -i -e "s/auth_port:.*,/auth_port: \"$API_AUTH_PORT\",/g" ./config/prod.secret.exs
sed -i -e "s/api_username:.*,/api_username: \"$API_USER\",/g" ./config/prod.secret.exs
sed -i -e "s/api_password:.*/api_password: \"$API_PASSWORD\"/g" ./config/prod.secret.exs
