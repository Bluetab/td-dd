use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_cx, TdCxWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_cx, TdCx.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_cx_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
