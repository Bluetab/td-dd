import Config

config :td_dd, TdDd.DataStructures.Search,
  es_scroll_size: 10_000,
  es_scroll_ttl: "1m",
  max_bulk_results: 100_000

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
    "system" => 50,
    "default" => 50
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
      store: TdDd.Search.Store,
      sources: [TdDd.Grants.GrantStructure],
      bulk_page_size: System.get_env("BULK_PAGE_SIZE_GRANTS", "500") |> String.to_integer(),
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
