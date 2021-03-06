defmodule TdDd.MockTaxonomyCache do
  @moduledoc false
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: MockTaxonomyCache)
  end

  def create_domain(%{name: name, id: id}) do
    Agent.update(MockTaxonomyCache, &Map.put(&1, name, id))
  end

  def get_parent_ids(domain_id), do: [domain_id]
end
