use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dq, TdDQWeb.Endpoint,
  http: [port: 4001],
  server: true

config :td_dq, hashing_module: TdDQ.DummyHashing

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dq, TdDQ.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_dq_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
