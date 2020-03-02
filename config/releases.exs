import Config

# Configure your database
config :td_cx, TdCx.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST")

config :td_cx, TdCx.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_cx, TdCx.Search.Cluster, url: System.fetch_env!("ES_URL")

config :td_cache, redis_host: System.fetch_env!("REDIS_HOST")

config :td_cx, :vault,
  token: System.fetch_env!("VAULT_TOKEN"),
  secrets_path: System.fetch_env!("VAULT_SECRETS_PATH")
