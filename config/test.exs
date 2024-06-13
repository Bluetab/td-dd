import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dd, TdDdWeb.Endpoint, server: false
config :td_dd, TdCxWeb.Endpoint, server: false
config :td_dd, TdDqWeb.Endpoint, server: false

# Track all Plug compile-time dependencies
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :td_dd, TdDd.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_dd_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :td_core, TdCore.Search.Cluster, api: ElasticsearchMock
config :td_core, TdCore.Search.IndexWorker, TdCore.Search.IndexWorkerMock

config :td_dd, :vault,
  token: "vault_secret_token1234",
  secrets_path: "secret/data/cx/"

config :td_dd, TdDd.DataStructures.HistoryManager, history_depth_days: 5

config :td_cluster, TdCluster.ClusterHandler, MockClusterHandler

config :vaultex, vault_addr: "http://vault:8200"

config :td_cache, :audit, stream: "audit:events:test"

config :td_cache, redis_host: "redis", port: 6380

# Print only warnings and errors during test
config :logger, level: :warn

# config :logger, :console, level: :debug

config :td_cluster, groups: [:dd]

config :td_cache, :event_stream, streams: []
