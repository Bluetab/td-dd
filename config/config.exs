# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Environment
config :td_cx, :env, Mix.env()

config :td_cx,
  ecto_repos: [TdCx.Repo]

# Configures the endpoint
config :td_cx, TdCxWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "QnGIoDqTQVcsX0mbc6Yw2n03R2FfJKbYjb1W3EqD9SK1Wklgk8R3oowCJwPVoRrm",
  render_errors: [view: TdCxWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: TdCx.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level]$levelpad $metadata$message") <> "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :td_cx, TdCx.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_cx, :auth_service,
  protocol: "http",
  users_path: "/api/users/",
  sessions_path: "/api/sessions/"

config :td_cx, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDdWeb.Router]
  }

config :td_cx, :audit_service,
  protocol: "http",
  audits_path: "/api/audits/"

config :td_cx, permission_resolver: TdCache.Permissions
config :td_cx, acl_cache: TdCache.AclCache

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
