defmodule TdDd.Search.MockIndexWorker do
  @moduledoc false

  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def calls, do: Agent.get(__MODULE__, &Enum.reverse(&1))

  def clear, do: Agent.update(__MODULE__, fn _ -> [] end)

  def reindex do
    Agent.update(__MODULE__, &[:reindex | &1])
  end

  def reindex(params) do
    Agent.update(__MODULE__, &[{:reindex, params} | &1])
  end

  def reindex_grants do
    Agent.update(__MODULE__, &[:reindex_grants | &1])
  end

  def reindex_grants(params) do
    Agent.update(__MODULE__, &[{:reindex_grants, params} | &1])
  end

  def reindex_rules(param) do
    Agent.update(__MODULE__, &[{:reindex_rules, param} | &1])
  end

  def reindex_implementations(param) do
    Agent.update(__MODULE__, &[{:reindex_implementations, param} | &1])
  end

  def delete(param) do
    Agent.update(__MODULE__, &[{:delete, param} | &1])
  end

  def delete_rules(param) do
    Agent.update(__MODULE__, &[{:delete_rules, param} | &1])
  end

  def delete_implementations(param) do
    Agent.update(__MODULE__, &[{:delete_implementations, param} | &1])
  end

  def ping(param) do
    Agent.update(__MODULE__, &[{:ping, param} | &1])
  end
end
