use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :td_dd, TdDqWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :td_dd, TdDd.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_dq_dev",
  hostname: "localhost",
  pool_size: 4

config :td_dd, qc_types_file: "static/qc_types_dev.json"
config :td_dd, qr_types_file: "static/qr_types_dev.json"

config :td_cache, redis_host: "localhost"

config :td_dd, :elasticsearch,
  search_service: TdDq.Search,
  es_host: "localhost",
  es_port: 9200,
  type_name: "doc"
