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

# Configures the maximum payload length for metadata loading
config :td_dd, TdDdWeb.BodyReader, max_payload_length: 100_000_000

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

# Configures the dq endpoint
config :td_dd, TdDqWeb.Endpoint,
  http: [port: 4004],
  url: [host: "localhost"],
  render_errors: [view: TdDqWeb.ErrorView, accepts: ~w(json)]

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

config :td_dd, TdDq.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_dd, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDdWeb.Router],
    "priv/static/swagger_cx.json" => [router: TdCxWeb.Router],
    "priv/static/swagger_dq.json" => [router: TdDqWeb.Router]
  }

config :codepagex, :encodings, [
  :ascii,
  ~r[iso8859]i,
  "VENDORS/MICSFT/WINDOWS/CP1252"
]

config :td_dd, permission_resolver: TdCache.Permissions
config :td_dd, index_worker: TdDd.Search.IndexWorker
config :td_dd, cx_index_worker: TdCx.Search.IndexWorker
config :td_dd, dq_index_worker: TdDq.Search.IndexWorker
config :td_dd, loader_worker: TdDd.Loader.Worker

# Default timeout increased for bulk metadata upload
config :td_dd, TdDd.Repo,
  pool_size: 16,
  timeout: 600_000

config :td_cache, :audit,
  service: "td_dd",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "dd",
  streams: [
    [group: "dd", key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
    [group: "dd", key: "domain:events", consumer: TdDd.Cache.DomainEventConsumer],
    [group: "dd", key: "template:events", consumer: TdDd.Search.IndexWorker],
    [group: "dq", key: "business_concept:events", consumer: TdDq.Search.IndexWorker],
    [group: "dq", key: "domain:events", consumer: TdDq.Cache.DomainEventConsumer],
    [group: "dq", key: "template:events", consumer: TdDq.Search.IndexWorker]
  ]

config :td_dd, :cache_cleaner,
  clean_on_startup: true,
  patterns: [
    "TdDd.DataStructures.Migrations:TD-2774",
    "TdDd.DataStructures.Migrations:td-2979",
    "TdDd.Structures.Migrations:TD-3066",
    "TdDq.RuleImplementations.Migrations:cache_structures",
    "data_fields:external_ids",
    "implementation:*",
    "rule_result:*",
    "source:*",
    "sources:ids_external_ids",
    "structures:external_ids:*"
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
    ],
    rule_cache_refresher: [
      schedule: "@hourly",
      task: {TdDq.Implementations.Tasks, :deprecate_implementations, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_indexer: [
      schedule: "@daily",
      task: {TdDq.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_remover: [
      schedule: "@hourly",
      task: {TdDq.Rules.RuleRemover, :archive_inactive_rules, []},
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
