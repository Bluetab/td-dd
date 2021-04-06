import Config

# Configure your database
config :td_dd, TdDd.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
  pool_size: System.get_env("DB_POOL_SIZE", "8") |> String.to_integer(),
  timeout: System.get_env("DB_TIMEOUT_MILLIS", "600000") |> String.to_integer()

config :td_dd, TdDd.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_dd, TdCx.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_dd, :vault,
  token: System.fetch_env!("VAULT_TOKEN"),
  secrets_path: System.fetch_env!("VAULT_SECRETS_PATH")

config :td_cache,
  redis_host: System.fetch_env!("REDIS_HOST"),
  port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
  password: System.get_env("REDIS_PASSWORD")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")

config :td_dd, import_dir: System.get_env("IMPORT_DIR")

config :td_dd, TdDd.Scheduler,
  jobs: [
    cache_refresher: [
      schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
      task: {TdDd.Cache.StructureLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    job_indexer: [
      schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
      task: {TdCx.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

config :td_dd, TdDd.Search.Cluster, url: System.fetch_env!("ES_URL")

with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
     password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
  config :td_dd, TdDd.Search.Cluster,
    username: username,
    password: password
end

config :td_dd, TdDd.Search.Cluster,
  aliases: %{
    jobs: System.get_env("ES_ALIAS_JOBS", "jobs"),
    structures: System.get_env("ES_ALIAS_STRUCTURES", "structures")
  },
  default_options: [
    timeout: System.get_env("ES_TIMEOUT", "5000") |> String.to_integer(),
    recv_timeout: System.get_env("ES_RECV_TIMEOUT", "40000") |> String.to_integer()
  ],
  default_settings: %{
    "number_of_shards" => System.get_env("ES_SHARDS", "1") |> String.to_integer(),
    "number_of_replicas" => System.get_env("ES_REPLICAS", "1") |> String.to_integer(),
    "refresh_interval" => System.get_env("ES_REFRESH_INTERVAL", "5s"),
    "index.indexing.slowlog.threshold.index.warn" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_WARN", "10s"),
    "index.indexing.slowlog.threshold.index.info" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_INFO", "5s"),
    "index.indexing.slowlog.threshold.index.debug" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_DEBUG", "2s"),
    "index.indexing.slowlog.threshold.index.trace" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_TRACE", "500ms"),
    "index.indexing.slowlog.level" => System.get_env("ES_INDEXING_SLOWLOG_LEVEL", "info"),
    "index.indexing.slowlog.source" => System.get_env("ES_INDEXING_SLOWLOG_SOURCE", "1000")
  }
