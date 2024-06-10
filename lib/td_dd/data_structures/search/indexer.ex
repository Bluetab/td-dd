defmodule TdDd.DataStructures.Search.Indexer do
  @moduledoc """
  Indexer for Structures.
  """

  alias TdCore.Search.IndexWorker
  alias TdDd.Search.StructureEnricher

  @index :structures

  def reindex(ids) do
    StructureEnricher.refresh()
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
