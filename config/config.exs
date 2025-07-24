# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

config :td_dd, Oban,
  prefix: "private",
  plugins: [{Oban.Plugins.Pruner, max_age: 2 * 24 * 60 * 60}],
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [xlsx_upload_queue: 10, delete_units: 10],
  repo: TdDd.Repo

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :td_dd, :time_zone, System.get_env("TZ", "Etc/UTC")

# Language
config :td_dd, :lang, "en"

# File upload base dir
config :td_dd, :file_upload_dir, Path.join(["priv", "upload"])

# Environment
config :td_dd, :env, Mix.env()
config :td_cluster, :env, Mix.env()
config :td_core, :env, Mix.env()

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
    (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level] $metadata$message") <>
      "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

# Configuration for Phoenix
config :phoenix, :json_library, Jason

config :td_dd, Truedat.Auth.Guardian,
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  aud: "truedat",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :codepagex, :encodings, [
  :ascii,
  ~r[iso8859]i,
  "VENDORS/MICSFT/WINDOWS/CP1252"
]

config :td_dd, TdDdWeb.CustomParsersPlug, max_payload_length: 100_000_000

config :td_dd, loader_worker: TdDd.Loader.Worker

config :td_dd, TdDd.Lineage,
  timeout: 90_000,
  nodes_timeout: 50_000

config :td_dd, TdDd.DataStructures.BulkUpdater, timeout_seconds: 600

config :td_dd, TdDd.ReferenceData,
  max_cols: 10,
  max_rows: 10_000

config :td_dd, TdDd.Loader.Worker, timeout: 30_000

# Default timeout increased for bulk metadata upload
config :td_dd, TdDd.Repo,
  pool_size: 4,
  timeout: 600_000

config :td_df_lib, lang: "en"

config :td_cache, :audit,
  service: "td_dd",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "dd",
  streams: [
    [group: "dd", key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
    [group: "dd", key: "template:events", consumer: TdCore.Search.IndexWorker],
    [group: "dq", key: "business_concept:events", consumer: TdCore.Search.IndexWorker],
    [group: "dq", key: "domain:events", consumer: TdDq.Cache.DomainEventConsumer],
    [group: "dq", key: "implementation_ref:events", consumer: TdDq.Cache.ImplementationLoader],
    [group: "dq", key: "template:events", consumer: TdCore.Search.IndexWorker]
  ]

config :td_dd, TdDd.Scheduler,
  jobs: [
    cache_cleaner: [
      schedule: "@reboot",
      task:
        {TdCache.CacheCleaner, :clean,
         [
           [
             "TdDd.DataStructures.Migrations:TD-2774",
             "TdDd.DataStructures.Migrations:td-2979",
             "TdDd.Structures.Migrations:TD-3066",
             "TdDq.RuleImplementations.Migrations:cache_structures",
             "data_fields:external_ids",
             "data_structure:keys:keep",
             "rule_result:*",
             "source:*",
             "sources:ids_external_ids",
             "structure_type:*",
             "structure_types:*",
             "structures:external_ids:*"
           ]
         ]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    cache_refresher: [
      schedule: "@hourly",
      task: {TdDd.Cache.StructureLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    job_indexer: [
      schedule: "@daily",
      task: {TdCore.Search.IndexWorker, :reindex, [:jobs, :all]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    implementation_cache_refresher: [
      schedule: "@hourly",
      task: {TdDq.Cache.ImplementationLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_indexer: [
      schedule: "@daily",
      task: {TdCore.Search.IndexWorker, :reindex, [:rules, :all]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    grant_indexer: [
      schedule: "@daily",
      task: {TdCore.Search.IndexWorker, :reindex, [:grants, :all]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    lineage_nodes_domains_ids_refresher: [
      schedule: "@hourly",
      task: {TdDd.Lineage.NodeQuery, :update_nodes_domains, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_remover: [
      schedule: "@hourly",
      task: {TdDq.Rules.RuleRemover, :archive_inactive_rules, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    catalog_history_purger: [
      schedule: "@daily",
      task: {TdDd.DataStructures.HistoryManager, :purge_history, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    force_update_structures_cache: [
      schedule: "@reboot",
      task: {TdDd.Cache.StructuresForceUpdate, :migrate, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    force_update_implementation_cache: [
      schedule: "@reboot",
      task: {TdDq.Cache.ImplementationsForceUpdate, :migrate, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    do_relation_between_impl_id_and_impl_ref: [
      schedule: "@reboot",
      task:
        {TdDq.Cache.ImplementationLoader, :implementation_ids_to_migrate_implementation_ref, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    expand_profile_values: [
      schedule: "@reboot",
      task: {TdDd.Profiles, :expand_profile_values, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    refresh_metadata_fields: [
      schedule: "@reboot",
      task: {TdDd.DataStructures.DataStructureTypes, :refresh_metadata_fields, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    update_domain_fields: [
      schedule: "@reboot",
      task: {Truedat.Jobs.UpdateDomainFields, :run, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

config :bodyguard, default_error: :forbidden
config :flop, repo: TdDd.Repo

import_config "metadata.exs"
import_config "profiling.exs"

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
