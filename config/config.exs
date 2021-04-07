# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Environment
config :td_dq, :env, Mix.env()

config :td_dq, permission_resolver: TdCache.Permissions
config :td_dq, index_worker: TdDq.Search.IndexWorker

config :td_dq, rule_removal: true
config :td_dq, rule_removal_frequency: 60 * 60 * 1000

# General application configuration
config :td_dq,
  ecto_repos: [TdDq.Repo]

# Configures the endpoint
config :td_dq, TdDqWeb.Endpoint,
  http: [port: 4004],
  url: [host: "localhost"],
  render_errors: [view: TdDqWeb.ErrorView, accepts: ~w(json)]

# Configures Auth module Guardian
config :td_dq, TdDq.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

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
config :phoenix_swagger, :json_library, Jason

config :td_dq, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDqWeb.Router]
  }

config :td_cache, :audit,
  service: "td_dq",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "dq",
  streams: [
    [key: "business_concept:events", consumer: TdDq.Search.IndexWorker],
    [key: "template:events", consumer: TdDq.Search.IndexWorker],
    [key: "domain:events", consumer: TdDq.Cache.DomainEventConsumer]
  ]

config :td_dq, :cache_cleaner,
  clean_on_startup: true,
  patterns: ["rule_result:*", "TdDq.RuleImplementations.Migrations:cache_structures"]

config :td_dq, TdDq.Scheduler,
  jobs: [
    reindexer: [
      schedule: "@daily",
      task: {TdDq.Search.IndexWorker, :reindex, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    refresh_cache: [
      schedule: "@hourly",
      task: {TdDq.Cache.ImplementationLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

# Import Elasticsearch config
import_config "elastic.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
