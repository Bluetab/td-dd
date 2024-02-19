defmodule TdDd.Release do
  @moduledoc """
  Release tasks to run Ecto migrations
  """

  @app :td_dd

  alias Ecto.Migrator

  def migrate do
    @app
    |> Application.get_env(TdDd.Repo)
    |> Keyword.get(:ssl, false)
    |> if do
      Application.ensure_all_started(:ssl)
    end

    for repo <- repos() do
      {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
