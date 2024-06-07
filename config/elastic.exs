import Config

config :td_dd, TdDd.DataStructures.Search,
  es_scroll_size: System.get_env("ES_SCROLL_SIZE", "10000") |> String.to_integer(),
  es_scroll_ttl: System.get_env("ES_SCROLL_TTL", "1m"),
  max_bulk_results: System.get_env("MAX_BULK_RESULTS", "100000") |> String.to_integer()

config :td_core, TdCore.Search.Cluster,
  # The default URL where Elasticsearch is hosted on your system.
  # Will be overridden by the `ES_URL` environment variable if set.
  url: "http://elastic:9200",

  # If you want to mock the responses of the Elasticsearch JSON API
  # for testing or other purposes, you can inject a different module
  # here. It must implement the Elasticsearch.API behaviour.
  api: Elasticsearch.API.HTTP,

  # Aggregations default
  aggregations: %{
    "domain" => System.get_env("AGG_DOMAIN_SIZE", "500") |> String.to_integer(),
    "user" => System.get_env("AGG_USER_SIZE", "500") |> String.to_integer(),
    "system" => System.get_env("AGG_SYSTEM_SIZE", "500") |> String.to_integer(),
    "default" => System.get_env("AGG_DEFAULT_SIZE", "500") |> String.to_integer(),
    "approved_by" => System.get_env("AGG_APPROVED_BY_SIZE", "500") |> String.to_integer(),
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
  },

  # If the variable delete_existing_index is set to false,
  # it will not be deleted in the case that there is no index in the hot swap process."
  delete_existing_index: System.get_env("DELETE_EXISTING_INDEX", "true") |> String.to_atom(),

  #  Store chunk size
  chunk_size_map: %{
    grants: System.get_env("GRANT_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
    grant_request:
      System.get_env("GRANT_REQUEST_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
    data_structure: System.get_env("STRUCTURE_STORE_CHUNK_SIZE", "1000") |> String.to_integer(),
    data_structure_version: System.get_env("DSV_STORE_CHUNK_SIZE", "1000") |> String.to_integer()
  },

  # The library used for JSON encoding/decoding.
  json_library: Jason,
  default_options: [
    timeout: 5_000,
    recv_timeout: 40_000
  ],
  aliases: %{
    grants: "grants",
    implementations: "implementations",
    jobs: "jobs",
    rules: "rules",
    structures: "structures",
    grant_requests: "grant_requests"
  },
  default_settings: %{
    "number_of_shards" => 5,
    "number_of_replicas" => 1,
    "refresh_interval" => "5s",
    "max_result_window" => 10_000,
    "index.indexing.slowlog.threshold.index.warn" => "10s",
    "index.indexing.slowlog.threshold.index.info" => "5s",
    "index.indexing.slowlog.threshold.index.debug" => "2s",
    "index.indexing.slowlog.threshold.index.trace" => "500ms",
    "index.indexing.slowlog.level" => "info",
    "index.indexing.slowlog.source" => "1000",
    "index.mapping.total_fields.limit" => "3000"
  },
  indexes: %{
    grants: %{
      dsv_no_sercheabled_fields: ["note"],
      grant_no_sercheabled_fields: ["detail"],
      store: TdDd.Search.Store,
      sources: [TdDd.Grants.GrantStructure],
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_GRANTS", "500") |> String.to_integer(),
      bulk_wait_interval: System.get_env("BULK_WAIT_INTERVAL_GRANTS", "0") |> String.to_integer(),
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            ngram: %{
              filter: ["lowercase", "asciifolding"],
              tokenizer: "ngram"
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            ngram: %{
              type: "ngram",
              min_gram: 3,
              max_gram: 3,
              token_chars: ["letter", "digit"]
            }
          }
        }
      }
    },
    implementations: %{
      template_scope: :ri,
      store: TdDq.Search.Store,
      sources: [TdDq.Implementations.Implementation],
      bulk_page_size:
        System.get_env("BULK_PAGE_SIZE_IMPLEMENTATIONS", "100") |> String.to_integer(),
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            default: %{
              type: "pattern",
              pattern: "\\W|_",
              lowercase: true
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          }
        }
      }
    },
    jobs: %{
      template_scope: :cx,
      store: TdCx.Search.Store,
      sources: [TdCx.Jobs.Job],
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_JOBS", "100") |> String.to_integer(),
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          }
        }
      }
    },
    rules: %{
      template_scope: :dq,
      store: TdDq.Search.Store,
      sources: [TdDq.Rules.Rule],
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_RULES", "100") |> String.to_integer(),
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            default: %{
              type: "pattern",
              pattern: "\\W|_",
              lowercase: true
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          }
        }
      }
    },
    structures: %{
      template_scope: :dd,
      store: TdDd.Search.Store,
      sources: [TdDd.DataStructures.DataStructureVersion],
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_STRUCTURES", "1000") |> String.to_integer(),
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            ngram: %{
              filter: ["lowercase", "asciifolding"],
              tokenizer: "ngram"
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            ngram: %{
              type: "ngram",
              min_gram: 3,
              max_gram: 3,
              token_chars: ["letter", "digit"]
            }
          }
        }
      }
    },
    grant_requests: %{
      template_scope: :gr,
      store: TdDd.Search.Store,
      sources: [TdDd.Grants.GrantRequest],
      bulk_page_size:
        System.get_env("BULK_PAGE_SIZE_GRANT_REQUESTS", "500") |> String.to_integer(),
      bulk_wait_interval: 0,
      bulk_action: "index",
      settings: %{
        analysis: %{
          analyzer: %{
            ngram: %{
              filter: ["lowercase", "asciifolding"],
              tokenizer: "ngram"
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          tokenizer: %{
            ngram: %{
              type: "ngram",
              min_gram: 3,
              max_gram: 3,
              token_chars: ["letter", "digit"]
            }
          }
        }
      }
    }
  }
