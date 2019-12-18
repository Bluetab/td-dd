use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_cx, TdCxWeb.Endpoint,
  secret_key_base: "8wcpqXTR4Lc98r9GkU8BRuoTRnZqCmZ0HYtqgmv6pC8RPV6NI78V9rIbZlD8S4YC"

# Configure your database
config :td_cx, TdCx.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_cx_prod",
  pool_size: 15
