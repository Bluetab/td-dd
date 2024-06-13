defmodule TdDq.Implementations.Search.Indexer do
  @moduledoc """
  Indexer for Implementations.
  """

  alias TdCore.Search.IndexWorker

  @index :implementations

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
