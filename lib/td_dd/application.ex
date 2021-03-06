defmodule TdDd.Application do
  @moduledoc false
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    env = Application.get_env(:td_dd, :env)

    # Define workers and child supervisors to be supervised
    children =
      [
        TdDd.Repo,
        TdCxWeb.Endpoint,
        TdDdWeb.Endpoint,
        TdDqWeb.Endpoint,
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
    TdCxWeb.Endpoint.config_change(changed, removed)
    TdDdWeb.Endpoint.config_change(changed, removed)
    TdDqWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp workers(:test), do: []

  defp workers(_env) do
    [
      # Task supervisor
      {Task.Supervisor, name: TdDd.TaskSupervisor},
      # Workers for indexing
      TdDd.Search.IndexWorker,
      TdDd.Search.StructureEnricher,
      # Worker for background bulk loading
      TdDd.Loader.Worker,
      # Task to recalculate data structure hashes on startup
      TdDd.DataStructures.Hasher,
      # Workers for cache loading
      TdDd.Cache.SystemLoader,
      TdDd.Cache.StructureLoader,
      TdDd.Cache.StructureTypeLoader,
      TdDd.Cache.DomainEventConsumer,
      # Lineage workers
      TdDd.Lineage.Import,
      TdDd.Lineage.GraphData,
      TdDd.Lineage,
      {TdCache.CacheCleaner, Application.get_env(:td_dd, :cache_cleaner, [])},
      # CX Workers
      TdCx.Search.IndexWorker,
      # DQ Workers
      TdDq.Cache.RuleLoader,
      TdDq.Search.IndexWorker,
      TdDq.Cache.DomainEventConsumer,
      # Scheduler for periodic tasks
      TdDd.Scheduler,
      TdDq.Cache.RuleMigrator
    ]
  end
end
