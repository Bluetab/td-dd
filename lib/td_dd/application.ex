defmodule TdDd.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    env = Application.get_env(:td_dd, :env)

    # Define workers and child supervisors to be supervised
    children =
      [
        TdDd.Repo,
        TdCxWeb.Endpoint,
        TdDdWeb.Endpoint,
        TdDqWeb.Endpoint
      ] ++ workers(env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdDd.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
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

      # Workers for search and indexing
      TdDd.Search.Cluster,
      TdDd.Search.IndexWorker,
      TdDd.Search.StructureEnricher,
      # Worker for background bulk loading
      TdDd.Loader.Worker,
      # Task to recalculate data structure hashes on startup
      TdDd.DataStructures.Hasher,
      # Workers for cache loading
      TdCx.Cache.SourcesLatestEvent,
      TdDd.Cache.SystemLoader,
      TdDd.Cache.StructureLoader,
      # Lineage workers
      TdDd.Lineage.Import,
      TdDd.Lineage.GraphData,
      TdDd.Lineage,
      # Bulk Updater worker
      TdDd.DataStructures.BulkUpdater,
      # CX Workers
      TdCx.Search.IndexWorker,
      # DQ Workers
      TdDq.Cache.ImplementationLoader,
      TdDq.Cache.RuleLoader,
      TdDq.Search.IndexWorker,
      # Scheduler for periodic tasks
      TdDd.Scheduler,
      TdDq.Cache.RuleMigrator,
      TdDd.Search.Tasks
    ]
  end
end
