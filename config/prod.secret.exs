use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_cx, TdCxWeb.Endpoint,
  secret_key_base: "8wcpqXTR4Lc98r9GkU8BRuoTRnZqCmZ0HYtqgmv6pC8RPV6NI78V9rIbZlD8S4YC"

# Configure your database
config :td_cx, TdCx.Repo,
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}",
  pool_size: 10

config :td_cx, TdCx.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_cache, redis_host: "${REDIS_HOST}"

config :td_cx, TdCx.Search.Cluster,
  url: "${ES_URL}"

config :td_cx, :vault,
  token: "${VAULT_TOKEN}",
  secrets_path: "${VAULT_SECRETS_PATH}"

config :vaultex, vault_addr: "http://${VAULT_SERVICE_HOST}:${VAULT_SERVICE_PORT}"
