import Config

# Configure your database
config :td_dd, TdDd.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: 10,
  timeout: 600_000

config :td_dd, TdDd.Auth.Guardian,
  secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_cache, redis_host: System.fetch_env!("REDIS_HOST")

config :td_dd, :audit_service,
  api_service: TdDdWeb.ApiServices.HttpTdAuditService,
  audit_host: System.fetch_env!("API_AUDIT_HOST"),
  audit_port: System.fetch_env!("API_AUDIT_PORT"),
  audit_domain: ""

config :td_cache, :event_stream,
  consumer_id: System.fetch_env!("HOSTNAME")

config :bolt_sips, Bolt,
  hostname: System.get_env("NEO4J_HOST"),
  basic_auth: [
    username: System.get_env("NEO4J_USER"),
    password: System.get_env("NEO4J_PASSWORD")
  ]

config :td_dd, import_dir: System.get_env("IMPORT_DIR")
