use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_dq, TdDqWeb.Endpoint,
  http: [port: 3004],
  url: [host: "localhost", port: 3004],
  server: true

config :td_dq, hashing_module: TdDq.DummyHashing

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_dq, TdDq.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "td_dq_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_dq, qc_types_file: "static/qc_types_test.json"
config :td_dq, qr_types_file: "static/qr_types_test.json"
