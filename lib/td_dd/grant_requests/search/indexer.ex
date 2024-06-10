defmodule TdDd.GrantRequests.Search.Indexer do
  @moduledoc """
  Indexer for Grant requests.
  """

  alias TdCore.Search.IndexWorker
  @index :grant_requests

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
