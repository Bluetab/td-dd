defmodule SqlServerRenamer do
  @moduledoc """
  Startup task to rename external_id of SQL server data structures to use
  schema and object names instead of their internal id.
  """
  use Task

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  require Logger

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, name: __MODULE__)
  end

  def run(_options) do
    case Repo.transaction(fn ->
           delete_invalid_structures()
           schemas = rename_schemas()
           tables = rename_tables()
           columns = rename_columns()
           schemas + tables + columns
         end) do
      {:ok, 0} -> Logger.info("No SQL Server structures to rename")
      {:ok, n} -> Logger.info("Renamed #{n} SQL Server structures")
      e -> e
    end
  end

  def delete_invalid_structures do
    from(dsv in DataStructureVersion)
    |> where([dsv], dsv.type in ["VIEW", "USER_TABLE"])
    |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
    |> where([_, ds], like(ds.external_id, "sqlserver://%"))
    |> select([dsv, ds], dsv)
    |> Repo.all()
    |> Enum.reject(&Map.has_key?(&1.metadata, "schema"))
    |> Enum.each(&Repo.delete!/1)

    Repo
    |> SQL.query("DELETE FROM data_structures WHERE id NOT IN (SELECT data_structure_id FROM data_structure_versions)")
  end

  def rename_schemas do
    from(dsv in DataStructureVersion)
    |> where([dsv], dsv.type == "Schema")
    |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
    |> where([_, ds], like(ds.external_id, "sqlserver://%"))
    |> where(
      [dsv, ds],
      fragment("reverse(split_part(reverse(?), '/', 1))", ds.external_id) != dsv.name
    )
    |> select([dsv, ds], {dsv.name, ds.external_id})
    |> Repo.all()
    |> Enum.uniq()
    |> Enum.map(&rename_schema/1)
    |> Enum.reject(fn {new, old} -> old == new end)
    |> Enum.group_by(fn {new, _} -> new end, fn {_, old} -> old end)
    |> Enum.map(&merge_structures/1)
    |> Enum.sum()
  end

  def rename_tables do
    from(dsv in DataStructureVersion)
    |> where([dsv], dsv.type in ["VIEW", "USER_TABLE"])
    |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
    |> where([_, ds], like(ds.external_id, "sqlserver://%"))
    |> where(
      [dsv, ds],
      fragment("reverse(split_part(reverse(?), '/', 1))", ds.external_id) != dsv.name
    )
    |> select([dsv, ds], {dsv.metadata, dsv.name, ds.external_id})
    |> Repo.all()
    |> Enum.uniq()
    |> Enum.map(&rename_table/1)
    |> Enum.reject(fn {new, old} -> old == new end)
    |> Enum.group_by(fn {new, _} -> new end, fn {_, old} -> old end)
    |> Enum.map(&merge_structures/1)
    |> Enum.sum()
  end

  def rename_columns do
    from(dsv in DataStructureVersion)
    |> where([dsv], dsv.class == "field")
    |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
    |> where([_, ds], like(ds.external_id, "sqlserver://%"))
    |> select([dsv, ds], {dsv.metadata, dsv.name, ds.external_id})
    |> Repo.all()
    |> Enum.uniq()
    |> Enum.map(&rename_column/1)
    |> Enum.reject(fn {new, old} -> old == new end)
    |> Enum.group_by(fn {new, _} -> new end, fn {_, old} -> old end)
    |> Enum.map(&merge_structures/1)
    |> Enum.sum()
  end

  defp rename_schema({name, external_id}) do
    prefix =
      external_id
      |> String.split("/")
      |> Enum.reverse()
      |> tl
      |> Enum.reverse()
      |> Enum.join("/")

    new_external_id = prefix <> "/" <> name

    {new_external_id, external_id}
  end

  defp rename_table({%{"schema" => schema}, name, external_id}) do
    prefix =
      external_id
      |> String.split("/")
      |> Enum.reverse()
      |> Enum.drop(2)
      |> Enum.reverse()

    new_external_id =
      (prefix ++ [schema, name])
      |> Enum.join("/")

    {new_external_id, external_id}
  end

  defp rename_column({%{"schema" => schema, "table" => table}, name, external_id}) do
    prefix =
      external_id
      |> String.split("/")
      |> Enum.reverse()
      |> Enum.drop(3)
      |> Enum.reverse()

    new_external_id =
      (prefix ++ [schema, table, name])
      |> Enum.join("/")

    {new_external_id, external_id}
  end

  defp merge_structures({external_id, old_external_ids}) do
    structures =
      old_external_ids
      |> Enum.map(&DataStructures.find_data_structure(%{external_id: &1}))
      |> Enum.sort_by(& &1.last_change_at)
      |> Enum.reverse()
      |> Repo.preload(:versions)

    [structure | structures_to_remove] = structures

    [latest | rest] =
      structures
      |> Enum.flat_map(& &1.versions)
      |> Enum.sort_by(& &1.updated_at)
      |> Enum.reverse()

    rest
    |> Enum.each(&Repo.delete!/1)

    update_data_structure_id(latest, structure.id)

    structures_to_remove
    |> Enum.each(&Repo.delete!/1)

    update_external_id(structure, external_id)
  end

  defp update_external_id(%DataStructure{id: id}, external_id) do
    Repo
    |> SQL.query(
      ~s(UPDATE "data_structures" SET "external_id" = $1 WHERE "id" = $2),
      [external_id, id]
    )
    |> row_count
  end

  defp update_data_structure_id(%DataStructureVersion{id: id}, data_structure_id) do
    Repo
    |> SQL.query(
      ~s(UPDATE "data_structure_versions" SET "data_structure_id" = $1 WHERE "id" = $2),
      [data_structure_id, id]
    )
    |> row_count
  end

  defp row_count({:ok, %{num_rows: num_rows}}), do: num_rows
end
