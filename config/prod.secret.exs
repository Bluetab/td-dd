use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_dq, TdDqWeb.Endpoint,
  secret_key_base: "PSTusjy0cud3K8KQ+8nCnGwLa8H5DwnvP2dtCO3TMx3mvKImONOnSGW9AeDDtD8E"

# Configure your database
config :td_dq, TdDq.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}",
  pool_size: 10

config :td_dq, TdDq.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_dq, TdDq.Search.Cluster, url: "${ES_URL}"

config :td_dq, :audit_service,
  api_service: TdDqWeb.ApiServices.HttpTdAuditService,
  audit_host: "${API_AUDIT_HOST}",
  audit_port: "${API_AUDIT_PORT}",
  audit_domain: ""

config :td_cache, redis_host: "${REDIS_HOST}"

config :td_cache, :event_stream,
  consumer_id: "${HOSTNAME}",
  consumer_group: "dq",
  streams: [
    [key: "business_concept:events", consumer: TdDq.Search.IndexWorker],
    [key: "template:events", consumer: TdDq.Search.IndexWorker]
  ]
