defmodule TdDq.Functions do
  @moduledoc """
  Context for data quality functions and operators
  """

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Functions.Bulk
  alias TdDq.Functions.Function

  def replace_all(%{} = params) do
    case Bulk.changeset(params) do
      %{valid?: false} = changeset ->
        {:error, changeset}

      changeset ->
        changeset
        |> Changeset.get_change(:functions)
        |> Enum.with_index()
        |> do_replace_all()
    end
  end

  defp do_replace_all(changesets_with_index) do
    Multi.new()
    |> Multi.delete_all(:delete_all, Function)
    |> insert_functions(changesets_with_index)
    |> Repo.transaction()
  end

  defp insert_functions(%Multi{} = multi, changesets_with_index)
       when is_list(changesets_with_index) do
    Enum.reduce(changesets_with_index, multi, fn {changeset, index}, multi ->
      Multi.insert(multi, index, changeset)
    end)
  end
end
