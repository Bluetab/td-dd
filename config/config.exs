# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :td_perms, permissions: [
  :is_admin,
  :create_acl_entry,
  :update_acl_entry,
  :delete_acl_entry,
  :create_domain,
  :update_domain,
  :delete_domain,
  :view_domain,
  :create_business_concept,
  :create_data_structure,
  :update_business_concept,
  :update_data_structure,
  :send_business_concept_for_approval,
  :delete_business_concept,
  :delete_data_structure,
  :publish_business_concept,
  :reject_business_concept,
  :deprecate_business_concept,
  :manage_business_concept_alias,
  :view_data_structure,
  :view_draft_business_concepts,
  :view_approval_pending_business_concepts,
  :view_published_business_concepts,
  :view_versioned_business_concepts,
  :view_rejected_business_concepts,
  :view_deprecated_business_concepts
]

# General application configuration
config :td_dq,
  ecto_repos: [TdDq.Repo]

# Configures the endpoint
config :td_dq, TdDqWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "/vMEDjTjLb9Re9GSKu6LYCE+qq7KuIvk2V65O1x4aMhStPltM87BMjeUw+zebVF3",
  render_errors: [view: TdDqWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: TdDq.PubSub,
           adapter: Phoenix.PubSub.PG2]

  # Configures Auth module Guardian
config :td_dq, TdDq.Auth.Guardian,
       allowed_algos: ["HS512"], # optional
       issuer: "tdauth",
       ttl: { 1, :hours },
       secret_key: "SuperSecretTruedat"

# Hashing algorithm
config :td_dq, hashing_module: Comeonin.Bcrypt

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :td_dq, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDqWeb.Router]
  }

config :td_dq, :audit_service,
  protocol: "http",
  audits_path: "/api/audits/"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
