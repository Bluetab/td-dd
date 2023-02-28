defmodule TdDdWeb.Resolvers.Tasks do
  @moduledoc """
  Absinthe resolvers for indexing stats
  """

  alias TdDd.Search.Tasks

  def tasks(_parent, _args, _resolution) do
    result =
      Tasks.ets_table()
      |> :ets.tab2list()
      |> Enum.map(fn {_id, task} -> task end)

    {:ok, result}
  end

  def task(_parent, %{id: id}, _resolution) do
    task =
      Tasks.ets_table()
      |> :ets.tab2list()
      |> Enum.find(fn {task_id, _task} -> "#{task_id}" == id end)
      |> case do
        {_, task} -> task
        _ -> nil
      end

    {:ok, task}
  end
end
