use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_dd, TdDdWeb.Endpoint,
  secret_key_base: "IY86+jKFXM/Ql/FhGrAgf5HIa2xBPsP1sVKX5Ip2Y4JIS73qMIb+qUBHhczIjxWB"

# Configure your database
config :td_dd, TdDd.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}",
  pool_size: 10,
  timeout: 15000

config :td_dd, TdDd.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_dd, :api_services_login,
  api_username: "${API_USER}",
  api_password: "${API_PASSWORD}"

config :td_dd, :auth_service, api_service: TdDdWeb.ApiServices.HttpTdAuthService,
  auth_host: "${API_AUTH_HOST}",
  auth_port: "${API_AUTH_PORT}",
  auth_domain: ""

config :td_dd, :elasticsearch,
  search_service: TdDd.Search,
  es_host: "${ES_HOST}",
  es_port: "${ES_PORT}",
  type_name: "doc"

config :td_perms, redis_uri: "${REDIS_URI}"

config :td_dd, :audit_service, api_service: TdDdWeb.ApiServices.HttpTdAuditService,
  audit_host: "${API_AUDIT_HOST}",
  audit_port: "${API_AUDIT_PORT}",
  audit_domain: ""
