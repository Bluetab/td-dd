import Config

config :td_core, TdCore.Search.Cluster,
  # The default URL where Elasticsearch is hosted on your system.
  # Will be overridden by the `ES_URL` environment variable if set.
  url: "http://elastic:9200",

  # If you want to mock the responses of the Elasticsearch JSON API
  # for testing or other purposes, you can inject a different module
  # here. It must implement the Elasticsearch.API behaviour.
  api: Elasticsearch.API.HTTP,

  # The library used for JSON encoding/decoding.
  json_library: Jason

config :td_core, TdCore.Search.Cluster,
  indexes: [
    grants: [
      dsv_no_searcheable_fields: ["note", "embeddings"],
      grant_no_searcheable_fields: ["detail"],
      store: TdDd.Search.Store,
      sources: [TdDd.Grants.GrantStructure],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    implementations: [
      template_scope: :ri,
      store: TdDq.Search.Store,
      sources: [TdDq.Implementations.Implementation],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    jobs: [
      template_scope: :cx,
      store: TdCx.Search.Store,
      sources: [TdCx.Jobs.Job],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    rules: [
      template_scope: :dq,
      store: TdDq.Search.Store,
      sources: [TdDq.Rules.Rule],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    structures: [
      template_scope: :dd,
      store: TdDd.Search.Store,
      sources: [TdDd.DataStructures.DataStructureVersion],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ],
    grant_requests: [
      dsv_disabled_fields: [:embeddings],
      template_scope: :gr,
      store: TdDd.Search.Store,
      sources: [TdDd.Grants.GrantRequest],
      bulk_action: "index",
      settings: %{
        analysis: %{
          tokenizer: %{
            custom_split_tokenizer: %{
              type: "pattern",
              pattern: "[\\s\\-_.:/]+"
            }
          },
          analyzer: %{
            default: %{
              type: "custom",
              tokenizer: "whitespace",
              filter: ["lowercase", "word_delimiter", "asciifolding"]
            },
            exact_analyzer: %{
              type: "custom",
              tokenizer: "custom_split_tokenizer",
              filter: ["lowercase", "asciifolding"]
            }
          },
          normalizer: %{
            sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
          },
          filter: %{
            es_stem: %{
              type: "stemmer",
              language: "light_spanish"
            }
          }
        }
      }
    ]
  ]
