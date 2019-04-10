defmodule TdDd.Application do
  @moduledoc false
  use Application
  alias TdDdWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(TdDd.Repo, []),
      # Start the endpoint when the application starts
      supervisor(TdDdWeb.Endpoint, []),
      # Worker for background indexing
      worker(TdDd.Search.IndexWorker, [TdDd.Search.IndexWorker]),
      # Worker for background bulk loading
      worker(TdDd.Loader.LoaderWorker, [TdDd.Loader.LoaderWorker])
    ]

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
end
