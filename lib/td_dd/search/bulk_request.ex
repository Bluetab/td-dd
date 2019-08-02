defmodule TdDd.Search.BulkRequest do
  @moduledoc """
  Transformations for bulk indexing requests
  """
  alias Jason, as: JSON
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Systems.System

  def new(%DataStructure{id: id} = ds) do
    metadata = metadata(ds, id)
    doc = ds |> ds.__struct__.search_fields() |> JSON.encode!()
    metadata <> "\n" <> doc
  end

  def new(%DataStructureVersion{data_structure_id: id} = dsv) do
    metadata = metadata(dsv, id)
    doc = dsv |> dsv.__struct__.search_fields() |> JSON.encode!()
    metadata <> "\n" <> doc
  end

  def new(%System{id: id} = system) do
    metadata = metadata(system, id)
    doc = system |> system.__struct__.search_fields() |> JSON.encode!()
    metadata <> "\n" <> doc
  end

  defp metadata(indexable, id, type \\ "doc")

  defp metadata(%{} = struct, id, type) do
    index_name = struct.__struct__.index_name(struct)
    metadata(index_name, id, type)
  end

  defp metadata(index_name, id, type) do
    ~s({"index": {"_id": #{id}, "_type": "#{type}", "_index": "#{index_name}"}})
  end
end
