use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :data_quality, DataQualityWeb.Endpoint,
  secret_key_base: "PSTusjy0cud3K8KQ+8nCnGwLa8H5DwnvP2dtCO3TMx3mvKImONOnSGW9AeDDtD8E"

# Configure your database
config :data_quality, DataQuality.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "data_quality_prod",
  hostname: "localhost",
  pool_size: 15
