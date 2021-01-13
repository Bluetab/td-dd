import Config

config :td_dq, TdDq.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer()

config :td_dq, TdDq.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_dq, TdDq.Search.Cluster, url: System.fetch_env!("ES_URL")

config :td_cache,
  redis_host: System.fetch_env!("REDIS_HOST"),
  port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
  password: System.get_env("REDIS_PASSWORD")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")

config :td_dq, TdDq.Scheduler,
  jobs: [
    reindexer: [
      schedule: System.get_env("ELASTIC_REFRESH_SCHEDULE", "@daily"),
      task: {TdDq.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    refresh_cache: [
      schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
      task: {TdDq.Cache.ImplementationLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]
