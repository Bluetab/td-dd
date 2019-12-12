defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDq.Repo

  @impl true
  def stream(schema) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> select([r], r)
    |> Repo.stream()
  end

  def stream(schema, ids) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^ids)
    |> select([r], r)
    |> Repo.stream()
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
