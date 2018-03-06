use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_dd, TdDDWeb.Endpoint,
  secret_key_base: "IY86+jKFXM/Ql/FhGrAgf5HIa2xBPsP1sVKX5Ip2Y4JIS73qMIb+qUBHhczIjxWB"

# Configure your database
config :td_dd, TdDD.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_dd_prod",
  hostname: "localhost",
  pool_size: 15

config :data_quality, TdDD.Auth.Guardian,
  allowed_algos: ["HS512"], # optional
  issuer: "tdauth",
  ttl: { 1, :hours },
  secret_key: "SuperSecretTruedat"
