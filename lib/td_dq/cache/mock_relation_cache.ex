defmodule TdDq.MockRelationCache do
  @moduledoc false
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: MockRelationCache)
  end

  def put_relation(relation) do
    Agent.update(MockRelationCache, &[relation | &1])
  end

  def get_resources(_resource_id, _resource_type, %{relation_type: rt_values}) do
    MockRelationCache
    |> Agent.get(& &1)
    |> Enum.filter(fn %{relation_type: relation_type} ->
      Enum.member?(rt_values, relation_type)
    end)
  end
end
