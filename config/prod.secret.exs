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
  username: "postgres",
  password: "postgres",
  database: "td_dd_prod",
  hostname: "localhost",
  pool_size: 10

config :td_dd, TdDd.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "SuperSecretTruedat"

config :td_dd, :api_services_login,
  api_username: "api-admin",
  api_password: "xxxxx"

config :td_dd, :auth_service, api_service: TdDdWeb.ApiServices.HttpTdAuthService,
  auth_host: "localhost",
  auth_port: "4001",
  auth_domain: ""

config :td_dd, :elasticsearch,
  search_service: TdDd.Search,
  es_host: "localhost",
  es_port: 9200,
  type_name: "doc"

config :td_dd, :audit_service, api_service: TdDdWeb.ApiServices.HttpTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""
