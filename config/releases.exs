import Config

config :td_dd, :time_zone, System.get_env("TZ", "Etc/UTC")

config :td_dd, TdDd.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
  pool_size: System.get_env("DB_POOL_SIZE", "16") |> String.to_integer(),
  timeout: System.get_env("DB_TIMEOUT_MILLIS", "600000") |> String.to_integer()

config :td_dd, Truedat.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_dd, :vault,
  token: System.fetch_env!("VAULT_TOKEN"),
  secrets_path: System.fetch_env!("VAULT_SECRETS_PATH")

config :td_cache,
  redis_host: System.fetch_env!("REDIS_HOST"),
  port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
  password: System.get_env("REDIS_PASSWORD")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")

config :td_dd, import_dir: System.get_env("IMPORT_DIR")

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
             "implementation:*",
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
      schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
      task: {TdDd.Cache.StructureLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    job_indexer: [
      schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
      task: {TdCx.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    implementation_cache_refresher: [
      schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
      task: {TdDq.Cache.ImplementationLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_cache_refresher: [
      schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
      task: {TdDq.Implementations.Tasks, :deprecate_implementations, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_indexer: [
      schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
      task: {TdDq.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    grant_indexer: [
      schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
      task: {TdDd.Search.IndexWorker, :reindex_grants, [:all]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    rule_remover: [
      schedule: System.get_env("RULE_REMOVAL_SCHEDULE", "@hourly"),
      task: {TdDq.Rules.RuleRemover, :archive_inactive_rules, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    catalog_history_purger: [
      schedule: System.get_env("CATALOG_HISTORY_PURGE_SCHEDULE", "@daily"),
      task: {TdDd.DataStructures.HistoryManager, :purge_history, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    force_update_structures_cache: [
      schedule: "@reboot",
      task: {TdDd.Cache.StructuresForceUpdate, :migrate, []},
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

config :td_dd, TdDd.Search.Cluster, url: System.fetch_env!("ES_URL")

with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
     password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
  config :td_dd, TdDd.Search.Cluster,
    username: username,
    password: password
end

config :td_dd, TdDd.Search.Cluster,
  aliases: %{
    grants: System.get_env("ES_ALIAS_GRANTS", "grants"),
    jobs: System.get_env("ES_ALIAS_JOBS", "jobs"),
    structures: System.get_env("ES_ALIAS_STRUCTURES", "structures"),
    implementations: System.get_env("ES_ALIAS_IMPLEMENTATIONS", "implementations"),
    rules: System.get_env("ES_ALIAS_RULES", "rules")
  },
  default_options: [
    timeout: System.get_env("ES_TIMEOUT", "5000") |> String.to_integer(),
    recv_timeout: System.get_env("ES_RECV_TIMEOUT", "40000") |> String.to_integer()
  ],
  default_settings: %{
    "number_of_shards" => System.get_env("ES_SHARDS", "1") |> String.to_integer(),
    "number_of_replicas" => System.get_env("ES_REPLICAS", "1") |> String.to_integer(),
    "refresh_interval" => System.get_env("ES_REFRESH_INTERVAL", "5s"),
    "max_result_window" => System.get_env("ES_MAX_RESULT_WINDOW", "10000") |> String.to_integer(),
    "index.indexing.slowlog.threshold.index.warn" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_WARN", "10s"),
    "index.indexing.slowlog.threshold.index.info" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_INFO", "5s"),
    "index.indexing.slowlog.threshold.index.debug" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_DEBUG", "2s"),
    "index.indexing.slowlog.threshold.index.trace" =>
      System.get_env("ES_INDEXING_SLOWLOG_THRESHOLD_TRACE", "500ms"),
    "index.indexing.slowlog.level" => System.get_env("ES_INDEXING_SLOWLOG_LEVEL", "info"),
    "index.indexing.slowlog.source" => System.get_env("ES_INDEXING_SLOWLOG_SOURCE", "1000")
  }

config :td_dd, TdDd.DataStructures.Search,
  es_scroll_size: System.get_env("ES_SCROLL_SIZE", "10000") |> String.to_integer(),
  es_scroll_ttl: System.get_env("ES_SCROLL_TTL", "1m"),
  max_bulk_results: System.get_env("MAX_BULK_RESULTS", "100000") |> String.to_integer()

config :td_dd, TdDd.DataStructures.HistoryManager,
  history_depth_days:
    System.get_env("CATALOG_HISTORY_DEPTH_DAYS", "")
    |> Integer.parse()
    |> (case do
          {days, ""} when days > 0 -> days
          _ -> nil
        end)

config :td_dd, TdDd.DataStructures.BulkUpdater,
  timeout_seconds:
    System.get_env("CSV_BULK_UPDATER_TIMEOUT_SECONDS", "600") |> String.to_integer()

config :td_dd, TdDdWeb.CustomParsersPlug,
  max_payload_length: System.get_env("MAX_PAYLOAD_LENGTH", "100000000") |> String.to_integer()

config :td_dd, TdDd.Lineage,
  nodes_timeout:
    System.get_env("LINEAGE_NODES_TIMEOUT")
    |> (case do
      nil -> nil
      "infinity" -> :infinity
      nodes_timeout when is_binary(nodes_timeout) -> String.to_integer(nodes_timeout)
    end),
  timeout: System.get_env("LINEAGE_TIMEOUT_MILLIS", "90000") |> String.to_integer()

config :td_dd, TdDd.ReferenceData,
  max_cols: System.get_env("REFERENCE_DATA_MAX_COLUMNS", "10") |> String.to_integer(),
  max_rows: System.get_env("REFERENCE_DATA_MAX_ROWS", "10000") |> String.to_integer()

config :td_dd, TdDd.Loader.Worker,
  timeout: System.get_env("SYNC_LOADER_TIMEOUT", "30000") |> String.to_integer()
