defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.Repo

  @chunk_size 1000

  @impl true
  def stream(schema) do
    schema
    |> where([dsv], is_nil(dsv.deleted_at))
    |> select([dsv], dsv)
    |> Repo.stream()
    |> Repo.stream_preload(@chunk_size, data_structure: :system)
  end

  def stream(schema, data_structure_ids) do
    schema
    |> where([dsv], is_nil(dsv.deleted_at))
    |> where([dsv], dsv.data_structure_id in ^data_structure_ids)
    |> select([dsv], dsv)
    |> Repo.stream()
    |> Repo.stream_preload(@chunk_size, data_structure: :system)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
