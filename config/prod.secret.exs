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
  username: "postgres",
  password: "postgres",
  database: "td_dq_prod",
  hostname: "localhost",
  pool_size: 10

config :td_dq, TdDq.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "SuperSecretTruedat"

config :td_dq, :audit_service, api_service: TdDqWeb.ApiServices.HttpTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""
