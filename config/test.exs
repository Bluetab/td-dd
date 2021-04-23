use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dd, TdDdWeb.Endpoint, server: false
config :td_dd, TdCxWeb.Endpoint, server: false
config :td_dd, TdDqWeb.Endpoint, server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dd, TdDd.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_dd_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :td_dd, permission_resolver: MockPermissionResolver

config :td_dd, index_worker: TdDd.Search.MockIndexWorker

config :td_dd, cx_index_worker: TdDd.Search.MockIndexWorker

config :td_dd, dq_index_worker: TdDd.Search.MockIndexWorker

config :td_dd, relation_cache: TdDq.MockRelationCache

config :td_dd, TdDd.Search.Cluster, api: TdDd.ElasticsearchMock

config :td_dd, :vault,
  token: "vault_secret_token1234",
  secrets_path: "secret/data/cx/"

config :vaultex, vault_addr: "http://vault:8200"

config :td_cache, :audit, stream: "audit:events:test"

config :td_cache, redis_host: "redis", port: 6380

config :td_cache, :event_stream, streams: []
