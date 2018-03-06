use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dd, TdDDWeb.Endpoint,
  http: [port: 3005],
  server: true


# Hashing algorithm just for testing porpouses
config :td_dd, hashing_module: TrueBG.DummyHashing

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dd, TdDD.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_dd_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
