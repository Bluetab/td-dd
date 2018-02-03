use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :data_dictionary, DataDictionaryWeb.Endpoint,
  secret_key_base: "IY86+jKFXM/Ql/FhGrAgf5HIa2xBPsP1sVKX5Ip2Y4JIS73qMIb+qUBHhczIjxWB"

# Configure your database
config :data_dictionary, DataDictionary.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "data_dictionary_prod",
  pool_size: 15
