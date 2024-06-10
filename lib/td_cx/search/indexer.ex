defmodule TdCx.Search.Indexer do
  @moduledoc """
  Indexer for Jobs.
  """

  alias TdCore.Search.IndexWorker

  @index :jobs

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
