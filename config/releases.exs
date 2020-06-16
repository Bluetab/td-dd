import Config

config :td_dq, TdDq.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer()

config :td_dq, TdDq.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_dq, TdDq.Search.Cluster, url: System.fetch_env!("ES_URL")

config :td_cache, redis_host: System.fetch_env!("REDIS_HOST")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")
