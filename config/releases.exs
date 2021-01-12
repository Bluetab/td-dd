import Config

# Configure your database
config :td_dd, TdDd.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: System.get_env("DB_POOL_SIZE", "8") |> String.to_integer(),
  timeout: System.get_env("DB_TIMEOUT_MILLIS", "600000") |> String.to_integer()

config :td_dd, TdDd.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

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
    ]
  ]
