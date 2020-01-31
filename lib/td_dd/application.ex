defmodule TdDd.Application do
  @moduledoc false
  use Application
  alias TdDdWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    env = Application.get_env(:td_dd, :env)

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the Ecto repository
        TdDd.Repo,
        # Start the endpoint when the application starts
        TdDdWeb.Endpoint,
        # Elasticsearch worker
        TdDd.Search.Cluster
      ] ++ workers(env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdDd.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp workers(:test), do: []

  defp workers(_env) do
    [
      # Path cache to improve indexing performance
      TdDd.DataStructures.PathCache,
      # Worker for background indexing
      TdDd.Search.IndexWorker,
      # Worker for background bulk loading
      TdDd.Loader.LoaderWorker,
      # Workers for cache loading
      TdDd.Cache.SystemLoader,
      TdDd.Cache.StructureLoader,
      TdDd.DataStructures.Hasher,
      {Bolt.Sips, Application.get_env(:bolt_sips, Bolt)},
      TdDd.Lineage.GraphData,
      TdDd.Lineage
    ]
  end
end
