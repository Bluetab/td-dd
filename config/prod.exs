use Mix.Config

config :td_dd, TdDdWeb.Endpoint,
  http: [port: 4005],
  server: true,
  version: Mix.Project.config()[:version]
