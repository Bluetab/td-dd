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
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}",
  pool_size: 10,
  timeout: 600_000

config :td_dd, TdDd.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_dd, :api_services_login,
  api_username: "${API_USER}",
  api_password: "${API_PASSWORD}"

config :td_dd, :auth_service,
  api_service: TdDdWeb.ApiServices.HttpTdAuthService,
  auth_host: "${API_AUTH_HOST}",
  auth_port: "${API_AUTH_PORT}",
  auth_domain: ""

config :td_cache, redis_host: "${REDIS_HOST}"

config :td_dd, TdDd.Search.Cluster, url: "${ES_URL}"

config :td_dd, :audit_service,
  api_service: TdDdWeb.ApiServices.HttpTdAuditService,
  audit_host: "${API_AUDIT_HOST}",
  audit_port: "${API_AUDIT_PORT}",
  audit_domain: ""

config :td_cache, :event_stream,
  consumer_id: "${HOSTNAME}",
  consumer_group: "dd",
  streams: [
    [key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
    [key: "template:events", consumer: TdDd.Search.IndexWorker]
  ]
