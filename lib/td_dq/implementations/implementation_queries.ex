defmodule TdDq.Implementations.ImplementationQueries do
  @moduledoc """
  Ecto queries for Implementations
  """

  import Ecto.Query

  alias TdCx.Sources.Source
  alias TdDq.Implementations.Implementation

  def implementation_sources_query(external_ids) do
    raw_sources_query = raw_implementation_sources_query()

    Implementation
    |> where(implementation_type: "default")
    |> join(:inner, [i], s in assoc(i, :dataset_sources))
    |> source_external_ids()
    |> union(^raw_sources_query)
    |> subquery()
    |> where(
      [s],
      fragment(
        "(? && ?)",
        ^external_ids,
        s.external_ids
      )
    )
    |> subquery()
  end

  def raw_implementation_sources_query do
    Implementation
    |> where(implementation_type: "raw")
    |> join(:inner, [i], s in Source, on: s.id == type(i.raw_content["source_id"], :integer))
    |> source_external_ids()
  end

  defp source_external_ids(q) do
    q
    |> group_by([i], i.id)
    |> select([i, s], %{
      implementation_id: i.id,
      external_ids: fragment("array_agg(distinct(?))", s.external_id)
    })
  end
end
