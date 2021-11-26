defmodule TdDd.Lineage.Graphs do
  @moduledoc """
  The Graphs context, handling storage and retrieval of graph drawings from the
  `TdDd.Repo`.
  """

  alias Graph.Drawing
  alias TdDd.Lineage.Graph, as: Graph
  alias TdDd.Repo

  @doc """
  Fetches a `Graph` where the primary key matches the given id.
  """
  def get!(id) do
    Repo.get!(Graph, id)
  end

  @doc """
  Inserts a new `Graph` created from a given `Drawing` and `hash`.
  """
  def create(%Drawing{} = data, hash) do
    %Graph{data: data, hash: hash}
    |> Repo.insert!()
  end

  @doc """
  Fetches a `Graph` with the given `hash`. Returns `nil` if no result was found.
  """
  def find_by_hash(hash) do
    Repo.get_by(Graph, %{hash: hash})
  end

  def find_by_hash!(hash) do
    Repo.get_by!(Graph, %{hash: hash})
  end
end
