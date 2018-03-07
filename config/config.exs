# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :td_dd,
  ecto_repos: [TdDd.Repo]

# Configures the endpoint
config :td_dd, TdDdWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "StwjLbs7tnN3G28P1N1+urbZaH0GX9Ps2y9mg3SOb9DdrWAEJdcKfkV8rKAxL2QF",
  render_errors: [view: TdDdWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: TdDd.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :td_dd, TdDd.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "SuperSecretTruedat"

config :canary, repo: TdDd.Repo,
  unauthorized_handler: {TdDd.Auth.Canary, :handle_unauthorized},
  not_found_handler: {TdDd.Auth.Canary, :handle_not_found}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
