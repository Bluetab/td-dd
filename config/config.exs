# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :data_quality,
  ecto_repos: [DataQuality.Repo]

# Configures the endpoint
config :data_quality, DataQualityWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "/vMEDjTjLb9Re9GSKu6LYCE+qq7KuIvk2V65O1x4aMhStPltM87BMjeUw+zebVF3",
  render_errors: [view: DataQualityWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: DataQuality.PubSub,
           adapter: Phoenix.PubSub.PG2]

  # Configures Auth module Guardian
config :data_quality, DataQuality.Auth.Guardian,
       allowed_algos: ["HS512"], # optional
       issuer: "tdauth",
       ttl: { 1, :hours },
       secret_key: "SuperSecretTruedat"

# Hashing algorithm
config :data_quality, hashing_module: Comeonin.Bcrypt

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
