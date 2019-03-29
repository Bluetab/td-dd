defmodule TdDq.MockRelationCache do
  @moduledoc false
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: MockRelationCache)
  end

  def put_relation(relation) do
    Agent.update(MockRelationCache, &[relation | &1])
  end

  def get_resources(_resource_id, _resource_type) do
    MockRelationCache
    |> Agent.get(& &1)
  end
end
