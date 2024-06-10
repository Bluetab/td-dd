defmodule TdDd.Grants.Search.Indexer do
  @moduledoc """
  Indexer for Grants.
  """

  alias TdCore.Search.IndexWorker

  @index :grants

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
