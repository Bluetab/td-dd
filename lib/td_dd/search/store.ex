defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @impl true
  def stream(DataStructureVersion) do
    query()
    |> Repo.stream()
    |> Stream.map(&preload/1)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def list(ids) do
    ids
    |> query()
    |> Repo.all()
    |> Enum.map(&preload/1)
  end

  def query do
    from(dsv in DataStructureVersion,
      where: is_nil(dsv.deleted_at),
      join: ds in assoc(dsv, :data_structure),
      join: s in assoc(ds, :system),
      select: {dsv, ds, s}
    )
  end

  def query(ids) do
    from(dsv in DataStructureVersion,
      where: is_nil(dsv.deleted_at),
      where: dsv.data_structure_id in ^ids,
      join: ds in assoc(dsv, :data_structure),
      join: s in assoc(ds, :system),
      select: {dsv, ds, s}
    )
  end

  defp preload({data_structure_version, data_structure, system}) do
    data_structure = Map.put(data_structure, :system, system)
    Map.put(data_structure_version, :data_structure, data_structure)
  end
end
