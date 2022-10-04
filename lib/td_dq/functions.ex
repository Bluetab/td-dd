defmodule TdDq.Functions do
  @moduledoc """
  Context for data quality functions and operators
  """

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Functions.Function

  def replace_all(%{"functions" => functions} = _params) do
    # %{"functions" => [%{"name" => _, "group" => _, "args" => _} | _]}

    {valid, invalid} =
      functions
      |> Enum.map(&Function.changeset/1)
      |> Enum.with_index()
      |> Enum.split_with(fn {%{valid?: valid}, _index} -> valid end)

    case invalid do
      [] ->
        Multi.new()
        |> Multi.delete_all(:delete_all, Function)
        |> insert_functions(valid)
        |> Repo.transaction()
    end
  end

  defp insert_functions(%Multi{} = multi, valid) when is_list(valid) do
    Enum.reduce(valid, multi, fn {changeset, index}, multi ->
      Multi.insert(multi, index, changeset)
    end)
  end
end
