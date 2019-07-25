use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dd, TdDdWeb.Endpoint,
  http: [port: 3005],
  server: true

# Hashing algorithm just for testing porpouses
config :td_dd, hashing_module: TrueBG.DummyHashing

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dd, TdDd.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_dd_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_dd, :api_services_login,
  api_username: "api-admin",
  api_password: "apipass"

config :td_dd, :auth_service,
  api_service: TdDdWeb.ApiServices.MockTdAuthService,
  auth_host: "localhost",
  auth_port: "4001",
  auth_domain: ""

config :td_dd, :elasticsearch,
  search_service: TdDd.Search.MockSearch,
  es_host: "elastic",
  es_port: 9200,
  type_name: "doc"

config :td_dd, permission_resolver: TdDd.Permissions.MockPermissionResolver
config :td_dd, index_worker: TdDd.Search.MockIndexWorker

config :td_cache, redis_host: "redis", port: 6380

config :td_dd, :audit_service,
  api_service: TdDdWeb.ApiServices.MockTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""
