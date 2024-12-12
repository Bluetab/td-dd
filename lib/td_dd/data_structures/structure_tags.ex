defmodule TdDd.DataStructures.StructureTags do
  @moduledoc """
  The StructureTags context.
  """
  import Ecto.Query

  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.Repo

  def list_structure_tags(clauses) do
    criteria_apply_order = [:min_id, :since, :size]

    criteria_apply_order
    |> Enum.filter(&Map.has_key?(clauses, &1))
    |> Enum.map(&{&1, Map.get(clauses, &1)})
    |> Enum.reduce(StructureTag, fn
      {:since, since}, q ->
        where(q, [st], st.updated_at >= ^since)
        |> order_by(asc: :updated_at)

      {:min_id, id}, q ->
        where(q, [st], st.id >= ^id)
        |> order_by(asc: :id)

      {:size, size}, q ->
        limit(q, ^size)
    end)
    |> Repo.all()
  end
end
