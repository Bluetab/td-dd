use Mix.Config

config :td_dd, TdDd.Search.Cluster,
  # The default URL where Elasticsearch is hosted on your system.
  # Will be overridden by the `ES_URL` environment variable if set.
  url: "http://elastic:9200",

  # If you want to mock the responses of the Elasticsearch JSON API
  # for testing or other purposes, you can inject a different module
  # here. It must implement the Elasticsearch.API behaviour.
  api: Elasticsearch.API.HTTP,

  # The library used for JSON encoding/decoding.
  json_library: Jason,
  default_options: [
    timeout: 5_000,
    recv_timeout: 40_000
  ],
  aliases: %{jobs: "jobs", structures: "structures"},
  default_settings: %{
    "number_of_shards" => 5,
    "number_of_replicas" => 1,
    "refresh_interval" => "5s",
    "index.indexing.slowlog.threshold.index.warn" => "10s",
    "index.indexing.slowlog.threshold.index.info" => "5s",
    "index.indexing.slowlog.threshold.index.debug" => "2s",
    "index.indexing.slowlog.threshold.index.trace" => "500ms",
    "index.indexing.slowlog.level" => "info",
    "index.indexing.slowlog.source" => "1000"
  },
  indexes: %{
    jobs: %{
      store: TdCx.Search.Store,
      sources: [TdCx.Jobs.Job],
      bulk_page_size: 100,
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
    structures: %{
      store: TdDd.Search.Store,
      sources: [TdDd.DataStructures.DataStructureVersion],
      bulk_page_size: 1000,
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
