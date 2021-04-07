# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
# General application configuration
use Mix.Config

# Environment
config :td_dd, :env, Mix.env()

# General application configuration
config :td_dd,
  ecto_repos: [TdDd.Repo]

# Configures the dd endpoint
config :td_dd, TdDdWeb.Endpoint,
  http: [port: 4005],
  url: [host: "localhost"],
  render_errors: [view: TdDdWeb.ErrorView, accepts: ~w(json)]

# Configures the cx endpoint
config :td_dd, TdCxWeb.Endpoint,
  http: [port: 4008],
  url: [host: "localhost"],
  render_errors: [view: TdCxWeb.ErrorView, accepts: ~w(json)]

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

config :td_dd, TdCx.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_dd, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDdWeb.Router],
    "priv/static/swagger_cx.json" => [router: TdCxWeb.Router]
  }

config :codepagex, :encodings, [
    :ascii,
    ~r[iso8859]i,
    "VENDORS/MICSFT/WINDOWS/CP1252"
]

config :td_dd, permission_resolver: TdCache.Permissions
config :td_dd, index_worker: TdDd.Search.IndexWorker
config :td_dd, cx_index_worker: TdCx.Search.IndexWorker

# Default timeout increased for bulk metadata upload
config :td_dd, TdDd.Repo,
  pool_size: 10,
  timeout: 600_000

config :td_cache, :audit,
  service: "td_dd",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "dd",
  streams: [
    [key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
    [key: "template:events", consumer: TdDd.Search.IndexWorker],
    [key: "domain:events", consumer: TdDd.Cache.DomainEventConsumer]
  ]

config :td_dd, :cache_cleaner,
  clean_on_startup: true,
  patterns: [
    "structures:external_ids:*",
    "data_fields:external_ids",
    "TdDd.DataStructures.Migrations:td-2979",
    "TdDd.DataStructures.Migrations:TD-2774",
    "sources:ids_external_ids",
    "source:*"
  ]

config :td_dd, TdDd.Scheduler,
  jobs: [
    cache_refresher: [
      schedule: "@hourly",
      task: {TdDd.Cache.StructureLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    job_indexer: [
      schedule: "@daily",
      task: {TdCx.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]


import_config "metadata.exs"
import_config "profiling.exs"

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
