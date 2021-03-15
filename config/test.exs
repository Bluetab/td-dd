use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dq, TdDqWeb.Endpoint,
  http: [port: 4104],
  server: true

config :td_dq, rule_removal: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dq, TdDq.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_dq_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_dq, :elasticsearch,
  search_service: TdDq.Search.MockSearch,
  es_host: "localhost",
  es_port: 9200,
  type_name: "doc"

config :td_dq, permission_resolver: MockPermissionResolver
config :td_dq, relation_cache: TdDq.MockRelationCache
config :td_dq, TdDq.Search.Cluster, api: TdDq.ElasticsearchMock

config :td_cache, redis_host: "redis", port: 6380

config :td_cache, :audit, stream: "audit:events:test"

config :td_cache, :event_stream, streams: []
