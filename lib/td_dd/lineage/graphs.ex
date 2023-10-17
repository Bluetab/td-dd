defmodule TdDd.Lineage.Graphs do
  @moduledoc """
  The Graphs context, handling storage and retrieval of graph drawings from the
  `TdDd.Repo`.
  """

  alias Graph.Drawing
  alias TdDd.Lineage.Graph, as: Graph
  alias TdDd.Lineage.Units
  alias TdDd.Repo

  @lowest_date ~U[0000-01-01 00:00:00Z]

  import Ecto.Query

  @doc """
  Fetches a `Graph` where the primary key matches the given id.
  """
  def get(id) do
    # convoluted left join with a last unit event one row table just to get
    # this information together with the searched graph, in one query.

    query =
      from g in Graph,
        left_join: ue in subquery(Units.last_updated_query()),
        where: g.id == ^id,
        select: %{graph: g, unit_last_updated: ue.inserted_at}

    with %{graph: g, unit_last_updated: unit_last_updated} <- Repo.one(query) do
      %{g | is_stale: :lt == DateTime.compare(g.updated_at, unit_last_updated || @lowest_date)}
    end
  end

  @doc """
  Inserts a new `Graph` created from a given `Drawing` and `hash`.
  """
  def create(%Drawing{excludes: excludes, opts: opts, ids: ids} = data, hash) do
    %Graph{
      data: data,
      hash: hash,
      params:
        Map.merge(
          %{ids: ids, excludes: excludes},
          opts
        )
    }
    |> Repo.insert!(
      on_conflict: {:replace, [:data, :updated_at]},
      conflict_target: [:hash]
    )
  end

  def non_stale_graph_by_hash_query(hash) do
    from g in Graph,
      where:
        g.hash == ^hash and
          g.updated_at >=
            fragment(
              "COALESCE(?, '-infinity')",
              subquery(Units.last_updated_query())
            )
  end

  @doc """
  Fetches a `Graph` with the given `hash`. Returns `nil` if no result was found.
  """
  def find_by_hash(hash) do
    hash
    |> non_stale_graph_by_hash_query()
    |> Repo.one()
  end

  def find_by_hash!(hash) do
    hash
    |> non_stale_graph_by_hash_query()
    |> Repo.one!()
  end
end
