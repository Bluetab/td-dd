defmodule TdDq.Application do
  @moduledoc false
  use Application
  alias TdDqWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    rule_remover_worker = %{
      id: TdDq.Rules.RuleRemover,
      start: {TdDq.Rules.RuleRemover, :start_link, []}
    }

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(TdDq.Repo, []),
      # Start the endpoint when the application starts
      supervisor(TdDqWeb.Endpoint, []),
      worker(TdDq.Cache.RuleLoader, []),
      worker(TdDq.Cache.RuleResultLoader, []),
      worker(TdDq.Cache.RuleIndexer, []),
      worker(TdDq.Search.IndexWorker, [TdDq.Search.IndexWorker]),
      # Elasticsearch worker
      TdDq.Search.Cluster,
      %{
        id: TdDq.CustomSupervisor,
        start:
          {TdDq.CustomSupervisor, :start_link,
           [%{children: [rule_remover_worker], strategy: :one_for_one}]},
        type: :supervisor
      }
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
