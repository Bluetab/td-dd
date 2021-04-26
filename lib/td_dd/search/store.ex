defmodule TdDd.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Dictionary
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.DataStructures.Paths
  alias TdDd.Repo

  @chunk_size 1000

  @impl true
  def stream(schema) do
    schema
    |> Paths.with_path(distinct: :data_structure_id)
    |> Repo.stream()
    |> Repo.stream_preload(@chunk_size, data_structure: :system)
  end

  def stream(schema, data_structure_ids) do
    schema
    |> Paths.with_path(distinct: :data_structure_id)
    |> where([dsv], dsv.data_structure_id in ^data_structure_ids)
    |> Repo.stream()
    |> Repo.stream_preload(@chunk_size, data_structure: :system)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
