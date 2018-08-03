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

config :td_dd, :auth_service,
  protocol: "http",
  users_path: "/api/users/",
  sessions_path: "/api/sessions/"

config :td_dd, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdDdWeb.Router]
  }

config :td_dd, :audit_service,
  protocol: "http",
  audits_path: "/api/audits/"

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
    :view_deprecated_business_concepts,
    :create_business_concept_link,
    :delete_business_concept_link
  ]

config :td_dd, permission_resolver: TdPerms.Permissions

import_config "metadata.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
