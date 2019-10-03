defmodule TdDq.Application do
  @moduledoc false
  use Application
  alias TdDqWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      TdDq.Repo,
      # Start the endpoint when the application starts
      TdDqWeb.Endpoint,
      # Cache workers
      TdDq.Cache.RuleLoader,
      TdDq.Cache.RuleResultLoader,
      # Elasticsearch and indexing workers
      TdDq.Search.Cluster,
      TdDq.Search.IndexWorker,
      # Worker to remove stale rules
      TdDq.Rules.RuleRemover
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdDq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
