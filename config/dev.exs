use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :td_cx, TdCxWeb.Endpoint,
  http: [port: 4008],
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
config :td_cx, TdCx.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_cx_dev",
  hostname: "localhost"

config :td_cache, redis_host: "localhost"

config :td_cx, :vault,
  token: "vault_secret_token1234",
  secrets_path: "secret/data/cx/"

config :vaultex, vault_addr: "http://0.0.0.0:8200"

config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/config",
      conn_opts: [context: "truedat"]
    }
  }
