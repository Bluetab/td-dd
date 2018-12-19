defmodule TdDd.MockTaxonomyCache do
  @moduledoc false
  use Agent

  alias TdDd.Audit.Event

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: MockTaxonomyCache)
  end

  def create_domain(%{name: name, id: id}) do
    Agent.update(MockTaxonomyCache, &(Map.put(&1, name, id)))
  end

  def get_domain_name_to_id_map do
    Agent.get(MockTaxonomyCache, &(&1))
  end

  def get_parent_ids(domain_id), do: [domain_id]
end
