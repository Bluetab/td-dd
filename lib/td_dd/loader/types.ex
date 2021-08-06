defmodule TdDd.Loader.Types do
  @moduledoc """
  Loader multi support for data structure types operations.
  """

  alias TdDd.DataStructures.DataStructureType
  alias TdDd.Repo

  @doc """
  Insert data structure type entries from structure records if no
  matching `DataStructureType` exists.
  """
  def insert_missing_types(_repo, _changes, structure_records, ts) do
    {:ok, do_insert_missing_types(structure_records, ts)}
  end

  defp do_insert_missing_types(structure_records, ts) do
    entries =
      structure_records
      |> MapSet.new(& &1.type)
      |> Enum.map(&%{name: &1, updated_at: ts, inserted_at: ts})

    Repo.insert_all(DataStructureType, entries, on_conflict: :nothing, returning: [:id, :name])
  end
end
