defmodule TdDq.Executions do
  @moduledoc """
  The executions context
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDq.Executions.{Audit, Execution, Group}
  alias TdDq.Repo

  @doc """
  Returns an execution group.
  """
  def get_group(%{"id" => id} = _params, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    Group
    |> preload(^preloads)
    |> Repo.get(id)
  end

  @doc """
  Returns a list of execution groups.
  """
  def list_groups(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params
    |> Enum.reduce(Group, fn
      {:created_by_id, id}, q -> where(q, [g], g.created_by_id == ^id)
    end)
    |> preload(^preloads)
    |> Repo.all()
  end

  @doc """
  Returns a list of executions.
  """
  def list_executions(params \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    params
    |> Enum.reduce(Execution, fn
      {:group_id, id}, q -> where(q, [e], e.group_id == ^id)
    end)
    |> preload(^preloads)
    |> Repo.all()
  end

  @doc """
  Create an execution group.
  """
  def create_group(%{} = params) do
    params
    |> Group.changeset()
    |> do_create_group()
  end

  defp do_create_group(%Changeset{} = changeset) do
    Multi.new()
    |> Multi.insert(:group, changeset)
    |> Multi.run(:audit, Audit, :execution_group_created, [changeset])
    |> Repo.transaction()
  end
end
