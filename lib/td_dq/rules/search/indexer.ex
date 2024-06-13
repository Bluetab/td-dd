defmodule TdDq.Rules.Search.Indexer do
  @moduledoc """
  Indexer for Rules.
  """

  alias TdCore.Search.IndexWorker

  @index :rules

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
