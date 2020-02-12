# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Environment
config :td_dd, :env, Mix.env()

# General application configuration
config :td_dd,
  ecto_repos: [TdDd.Repo]

# Configures the endpoint
config :td_dd, TdDdWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "StwjLbs7tnN3G28P1N1+urbZaH0GX9Ps2y9mg3SOb9DdrWAEJdcKfkV8rKAxL2QF",
  render_errors: [view: TdDdWeb.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
# set EX_LOGGER_FORMAT environment variable to override Elixir's Logger format
# (without the 'end of line' character)
# EX_LOGGER_FORMAT='$date $time [$level] $message'
config :logger, :console,
  format:
    (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level]$levelpad $metadata$message") <>
      "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

# Configuration for Phoenix
config :phoenix, :json_library, Jason
config :phoenix_swagger, json_library: Jason

config :td_dd, TdDd.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_dd, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDdWeb.Router]
  }

config :td_dd, :audit_service,
  api_service: TdDdWeb.ApiServices.HttpTdAuditService,
  audit_domain: "",
  audit_host: "localhost",
  audit_port: "4007",
  audits_path: "/api/audits/",
  protocol: "http"

config :td_dd, permission_resolver: TdCache.Permissions
config :td_dd, index_worker: TdDd.Search.IndexWorker
config :td_dd, import_dir: "/import"

# Default timeout increased for bulk metadata upload
config :td_dd, TdDd.Repo,
  pool_size: 10,
  timeout: 600_000

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "dd",
  streams: [
    [key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
    [key: "template:events", consumer: TdDd.Search.IndexWorker]
  ]

config :bolt_sips, Bolt,
  hostname: "neo",
  basic_auth: [username: "neo4j", password: "f00B4Rb4z"],
  pool_size: 3,
  timeout: 60_000,
  idle_interval: 60_000

config :tzdata, :autoupdate, :disabled

config :td_dd, :cache_cleaner,
  clean_on_startup: true,
  patterns: ["structures:external_ids:*", "data_fields:external_ids"]

import_config "metadata.exs"
import_config "profiling.exs"

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
