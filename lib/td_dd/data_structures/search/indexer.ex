defmodule TdDd.DataStructures.Search.Indexer do
  @moduledoc """
  Indexer for Structures.
  """

  alias TdCore.Search.IndexWorker
  alias TdDd.DataStructures.RecordEmbeddings
  alias TdDd.Search.StructureEnricher

  @index :structures
  @schedule_in 60 * 30

  def reindex(ids) do
    StructureEnricher.refresh()
    IndexWorker.reindex(@index, ids)
    upsert_record_embeddings(ids)

    :ok
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end

  def put_embeddings(ids) do
    StructureEnricher.refresh()
    IndexWorker.put_embeddings(@index, ids)
    :ok
  end

  defp upsert_record_embeddings(:all), do: :noop

  defp upsert_record_embeddings(ids) do
    RecordEmbeddings.upsert_from_structures_async(ids, schedule_in: @schedule_in)
  end
end
