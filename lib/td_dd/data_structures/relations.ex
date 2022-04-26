defmodule TdDd.DataStructures.Relations do
  @moduledoc """
  The data structure Relations context.
  """

  import Ecto.Query

  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo

  def list_data_structure_relations(args \\ %{}) do
    args
    |> Enum.reduce(DataStructureRelation, fn
      {:since, since}, q -> where(q, [dsr], dsr.updated_at >= ^since)
      {:min_id, id}, q -> where(q, [dsr], dsr.id >= ^id)
      {:order_by, "id"}, q -> order_by(q, :id)
      {:limit, limit}, q -> limit(q, ^limit)
      {:types, type_names}, q -> where_type_name_in(q, type_names)
    end)
    |> Repo.all()
  end

  defp where_type_name_in(q, type_names) do
    sq = RelationTypes.relation_type_query(names: type_names, select: :id)
    where(q, [dsr], dsr.relation_type_id in subquery(sq))
  end
end
