# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :td_cx,
  ecto_repos: [TdCx.Repo]

# Configures the endpoint
config :td_cx, TdCxWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "QnGIoDqTQVcsX0mbc6Yw2n03R2FfJKbYjb1W3EqD9SK1Wklgk8R3oowCJwPVoRrm",
  render_errors: [view: TdCxWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: TdCx.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
