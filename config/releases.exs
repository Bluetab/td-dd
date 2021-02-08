import Config

# Configure your database
config :td_cx, TdCx.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST")

config :td_cx, TdCx.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_cx, :vault,
  token: System.fetch_env!("VAULT_TOKEN"),
  secrets_path: System.fetch_env!("VAULT_SECRETS_PATH")

config :td_cache,
  redis_host: System.fetch_env!("REDIS_HOST"),
  port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
  password: System.get_env("REDIS_PASSWORD")

config :td_cx, TdCx.Scheduler,
  jobs: [
    [
      schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
      task: {TdCx.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

config :td_cx, TdCx.K8s, namespace: System.get_env("K8S_NAMESPACE", "default")

config :td_cx, TdCx.Search.Cluster, url: System.fetch_env!("ES_URL")

with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
     password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
  config :td_cx, TdCx.Search.Cluster,
    username: username,
    password: password
end
