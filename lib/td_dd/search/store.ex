defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo
  alias TdDd.Search.Indexable

  @impl true
  def stream(Indexable) do
    query()
    |> Repo.stream()
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
  end

  def query do
    from(dsv in DataStructureVersion,
      where: is_nil(dsv.deleted_at),
      join: ds in assoc(dsv, :data_structure),
      join: s in assoc(ds, :system),
      select: %Indexable{data_structure_version: dsv, data_structure: ds, system: s}
    )
  end

  def query(ids) do
    from(dsv in DataStructureVersion,
      where: is_nil(dsv.deleted_at),
      where: dsv.data_structure_id in ^ids,
      join: ds in assoc(dsv, :data_structure),
      join: s in assoc(ds, :system),
      select: %Indexable{data_structure_version: dsv, data_structure: ds, system: s}
    )
  end
end
