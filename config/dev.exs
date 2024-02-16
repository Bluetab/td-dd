import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :td_dd, TdDdWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :td_dd, TdCxWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :td_dd, TdDqWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :td_dd, TdDd.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_dd_dev",
  hostname: "postgres",
  stacktrace: true

config :td_cache, redis_host: "redis"

config :td_dd, :vault,
  token: "vault_secret_token1234",
  secrets_path: "secret/data/cx/"

config :vaultex, vault_addr: "http://vault:8200"
