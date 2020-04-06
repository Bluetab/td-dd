use Mix.Config

config :td_dq, TdDqWeb.Endpoint,
  http: [port: 4004],
  server: true,
  version: Mix.Project.config()[:version]
