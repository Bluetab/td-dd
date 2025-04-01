import Config

config :td_dd, :time_zone, System.get_env("TZ", "Etc/UTC")

config :td_cluster, groups: [:dd]

if config_env() == :prod do
  config :td_dd, TdDd.Repo,
    username: System.fetch_env!("DB_USER"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST"),
    port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
    pool_size: System.get_env("DB_POOL_SIZE", "16") |> String.to_integer(),
    timeout: System.get_env("DB_TIMEOUT_MILLIS", "600000") |> String.to_integer(),
    ssl: System.get_env("DB_SSL", "") |> String.downcase() == "true",
    ssl_opts: [
      cacertfile: System.get_env("DB_SSL_CACERTFILE", ""),
      verify:
        System.get_env("DB_SSL_VERIFY", "verify_none") |> String.downcase() |> String.to_atom(),
      server_name_indication: System.get_env("DB_HOST") |> to_charlist(),
      certfile: System.get_env("DB_SSL_CLIENT_CERT", ""),
      keyfile: System.get_env("DB_SSL_CLIENT_KEY", ""),
      versions: [
        System.get_env("DB_SSL_VERSION", "tlsv1.2") |> String.downcase() |> String.to_atom()
      ]
    ]

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
  config :td_core, TdCore.Search.Cluster, url: System.fetch_env!("ES_URL")

  config :td_dd, TdDd.DataStructures.HistoryManager,
    history_depth_days:
      System.get_env("CATALOG_HISTORY_DEPTH_DAYS", "")
      |> Integer.parse()
      |> (case do
            {days, ""} when days > 0 -> days
            _ -> nil
          end)

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
        task: {TdCore.Search.IndexWorker, :reindex, [:jobs, :all]},
        run_strategy: Quantum.RunStrategy.Local
      ],
      implementation_cache_refresher: [
        schedule: System.get_env("CACHE_REFRESH_SCHEDULE", "@hourly"),
        task: {TdDq.Cache.ImplementationLoader, :refresh, []},
        run_strategy: Quantum.RunStrategy.Local
      ],
      rule_indexer: [
        schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
        task: {TdCore.Search.IndexWorker, :reindex, [:rules, :all]},
        run_strategy: Quantum.RunStrategy.Local
      ],
      grant_indexer: [
        schedule: System.get_env("ES_REFRESH_SCHEDULE", "@daily"),
        task: {TdCore.Search.IndexWorker, :reindex, [:grants, :all]},
        run_strategy: Quantum.RunStrategy.Local
      ],
      lineage_nodes_domains_ids_refresher: [
        schedule: System.get_env("LINEAGE_NODES_DOMAINS_IDS_REFRESHER", "@hourly"),
        task: {TdDd.Lineage.NodeQuery, :update_nodes_domains, []},
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

  with username when not is_nil(username) <- System.get_env("ES_USERNAME"),
       password when not is_nil(password) <- System.get_env("ES_PASSWORD") do
    config :td_dd, TdDd.Search.Cluster,
      username: username,
      password: password
  end

  with api_key when not is_nil(api_key) <- System.get_env("ES_API_KEY") do
    config :td_core, TdCore.Search.Cluster,
      default_headers: [{"Authorization", "ApiKey #{api_key}"}]
  end

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
end

config :td_dd, Oban, prefix: System.get_env("OBAN_DB_SCHEMA", "private")

config :td_dd, oban_create_schema: System.get_env("OBAN_CREATE_SCHEMA", "true") == "true"

config :td_dd, TdDd.Lineage.Import.Loader,
  nodes_chunk_size: System.get_env("NODES_CHUNK_SIZE", "10000") |> String.to_integer(),
  units_chunk_size: System.get_env("UNITS_CHUNK_SIZE", "10000") |> String.to_integer(),
  edges_chunk_size: System.get_env("EDGES_CHUNK_SIZE", "500") |> String.to_integer()

config :td_dd, TdDd.DataStructures.Search,
  es_scroll_size: System.get_env("ES_SCROLL_SIZE", "10000") |> String.to_integer(),
  es_scroll_ttl: System.get_env("ES_SCROLL_TTL", "1m"),
  max_bulk_results: System.get_env("MAX_BULK_RESULTS", "100000") |> String.to_integer()

config :td_dd, TdDd.Search.Store,
  #  Store chunk size
  grants: System.get_env("GRANT_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
  grant_request: System.get_env("GRANT_REQUEST_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
  data_structure: System.get_env("STRUCTURE_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
  data_structure_version: System.get_env("DSV_STORE_CHUNK_SIZE", "1000") |> String.to_integer()

config :td_dd, TdDq.Search.Store,
  #  Store chunk size
  implementations:
    System.get_env("IMPLEMENTATION_STORE_CHUNK_SIZE", "1000") |> String.to_integer()

optional_ssl_options =
  case System.get_env("ES_SSL") do
    "true" ->
      cacertfile =
        case System.get_env("ES_SSL_CACERTFILE", "generated") do
          "generated" -> :certifi.cacertfile()
          file -> file
        end

      [
        ssl: [
          cacertfile: cacertfile,
          verify:
            System.get_env("ES_SSL_VERIFY", "verify_none")
            |> String.downcase()
            |> String.to_atom()
        ]
      ]

    _ ->
      []
  end

elastic_default_options =
  [
    timeout: System.get_env("ES_TIMEOUT", "5000") |> String.to_integer(),
    recv_timeout: System.get_env("ES_RECV_TIMEOUT", "40000") |> String.to_integer()
  ] ++ optional_ssl_options

config :td_core, TdCore.Search.Cluster,
  # If the variable delete_existing_index is set to false,
  # it will not be deleted in the case that there is no index in the hot swap process."
  delete_existing_index: System.get_env("DELETE_EXISTING_INDEX", "true") |> String.to_atom(),
  aliases: %{
    grants: System.get_env("ES_ALIAS_GRANTS", "grants"),
    jobs: System.get_env("ES_ALIAS_JOBS", "jobs"),
    structures: System.get_env("ES_ALIAS_STRUCTURES", "structures"),
    implementations: System.get_env("ES_ALIAS_IMPLEMENTATIONS", "implementations"),
    rules: System.get_env("ES_ALIAS_RULES", "rules"),
    grant_requests: System.get_env("ES_ALIAS_GRANT_REQUESTS", "grant_requests")
  },
  default_options: elastic_default_options,
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
    # "index.indexing.slowlog.level" => System.get_env("ES_INDEXING_SLOWLOG_LEVEL", "info"),
    "index.indexing.slowlog.source" => System.get_env("ES_INDEXING_SLOWLOG_SOURCE", "1000"),
    "index.mapping.total_fields.limit" => System.get_env("ES_MAPPING_TOTAL_FIELDS_LIMIT", "3000")
  }

config :td_core, TdCore.Search.Cluster,
  indexes: [
    grants: [
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_GRANTS", "500") |> String.to_integer(),
      bulk_wait_interval: System.get_env("BULK_WAIT_INTERVAL_GRANTS", "0") |> String.to_integer()
    ],
    implementations: [
      bulk_page_size:
        System.get_env("BULK_PAGE_SIZE_IMPLEMENTATIONS", "100") |> String.to_integer(),
      bulk_wait_interval:
        System.get_env("BULK_WAIT_INTERVAL_IMPLEMENTATIONS", "0") |> String.to_integer()
    ],
    jobs: [
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_JOBS", "100") |> String.to_integer(),
      bulk_wait_interval: System.get_env("BULK_WAIT_INTERVAL_JOBS", "0") |> String.to_integer()
    ],
    rules: [
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_RULES", "100") |> String.to_integer(),
      bulk_wait_interval: System.get_env("BULK_WAIT_INTERVAL_RULES", "0") |> String.to_integer()
    ],
    structures: [
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_STRUCTURES", "500") |> String.to_integer(),
      bulk_wait_interval:
        System.get_env("BULK_WAIT_INTERVAL_STRUCTURES", "0") |> String.to_integer(),
      apply_lang_settings:
        System.get_env("APPLY_LANG_SETTINGS_STRUCTURES", "true") |> String.downcase() == "true"
    ],
    grant_requests: [
      bulk_page_size:
        System.get_env("BULK_PAGE_SIZE_GRANT_REQUESTS", "500") |> String.to_integer(),
      bulk_wait_interval:
        System.get_env("BULK_WAIT_INTERVAL_GRANT_REQUESTS", "0") |> String.to_integer()
    ]
  ]

config :td_core, TdCore.Search.Cluster,
  # Aggregations default
  aggregations: %{
    "domain" => System.get_env("AGG_DOMAIN_SIZE", "500") |> String.to_integer(),
    "user" => System.get_env("AGG_USER_SIZE", "500") |> String.to_integer(),
    "system" => System.get_env("AGG_SYSTEM_SIZE", "500") |> String.to_integer(),
    "default" => System.get_env("AGG_DEFAULT_SIZE", "500") |> String.to_integer(),
    "source_external_id" =>
      System.get_env("AGG_SOURCE_EXTERNAL_ID_SIZE", "500") |> String.to_integer(),
    "source_type" => System.get_env("AGG_SOURCE_TYPE_SIZE", "500") |> String.to_integer(),
    "status" => System.get_env("AGG_STATUS_SIZE", "500") |> String.to_integer(),
    "type" => System.get_env("AGG_TYPE_SIZE", "500") |> String.to_integer(),
    "default_note" => System.get_env("AGG_DEFAULT_NOTE_SIZE", "500") |> String.to_integer(),
    "default_metadata" =>
      System.get_env("AGG_DEFAULT_METADATA_SIZE", "500") |> String.to_integer(),
    "system.name.raw" => System.get_env("AGG_SYSTEM_NAME_RAW_SIZE", "500") |> String.to_integer(),
    "group.raw" => System.get_env("AGG_GROUP_RAW_SIZE", "500") |> String.to_integer(),
    "type.raw" => System.get_env("AGG_TYPE_RAW_SIZE", "500") |> String.to_integer(),
    "confidential.raw" =>
      System.get_env("AGG_CONFIDENTIAL_RAW_SIZE", "500") |> String.to_integer(),
    "note_status" => System.get_env("AGG_NOTE_STATUS_SIZE", "500") |> String.to_integer(),
    "class.raw" => System.get_env("AGG_CLASS_RAW_SIZE", "500") |> String.to_integer(),
    "field_type.raw" => System.get_env("AGG_FIELD_TYPE_RAW_SIZE", "500") |> String.to_integer(),
    "with_content.raw" =>
      System.get_env("AGG_WITH_CONTENT_RAW_SIZE", "500") |> String.to_integer(),
    "tags.raw" => System.get_env("AGG_TAGS_RAW_SIZE", "500") |> String.to_integer(),
    "linked_concepts" => System.get_env("AGG_LINKED_CONCEPTS_SIZE", "500") |> String.to_integer(),
    "taxonomy" => System.get_env("AGG_TAXONOMY_SIZE", "500") |> String.to_integer(),
    "hierarchy" => System.get_env("AGG_HIERARCHY_SIZE", "500") |> String.to_integer(),
    "with_profiling.raw" =>
      System.get_env("AGG_WITH_PROFILING_RAW_SIZE", "500") |> String.to_integer(),
    "execution_result_info.result_text" =>
      System.get_env("AGG_EXECUTION_RESULT_INFO_RESULT_TEXT_SIZE", "500") |> String.to_integer(),
    "rule" => System.get_env("AGG_RULE_SIZE", "500") |> String.to_integer(),
    "result_type.raw" => System.get_env("AGG_RESULT_TYPE_SIZE", "500") |> String.to_integer(),
    "structure_taxonomy" =>
      System.get_env("AGG_STRUCTURE_TAXONOMY_SIZE", "500") |> String.to_integer(),
    "linked_structures_ids" =>
      System.get_env("AGG_LINKED_STRUCTURES_IDS_SIZE", "500") |> String.to_integer(),
    "current_status" => System.get_env("AGG_CURRENT_STATUS_SIZE", "500") |> String.to_integer(),
    "pending_removal.raw" =>
      System.get_env("AGG_PENDING_REMOVAL_RAW_SIZE", "500") |> String.to_integer(),
    "system_external_id" =>
      System.get_env("AGG_SYSTEM_EXTERNAL_ID_SIZE", "500") |> String.to_integer(),
    "active.raw" => System.get_env("AGG_ACTIVE_RAW_SIZE", "500") |> String.to_integer(),
    "df_label.raw" => System.get_env("AGG_DF_LABEL_RAW_SIZE", "500") |> String.to_integer()
  }
