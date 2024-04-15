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
    "domain" => 50,
    "user" => 50,
    "system" => 50
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
