use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_cx, TdCxWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_cx, TdCx.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_cx_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_cx, :auth_service, api_service: TdCxWeb.ApiServices.MockTdAuthService
config :td_cx, permission_resolver: TdCx.Permissions.MockPermissionResolver

config :td_cx, TdCx.Search.Cluster, api: TdCx.ElasticsearchMock

config :td_cache, redis_host: "redis"

config :td_cx, :vault,
  token: "vault_secret_token1234",
  secrets_path: "secret/data/cx/"

config :vaultex, vault_addr: "http://vault:8200"

