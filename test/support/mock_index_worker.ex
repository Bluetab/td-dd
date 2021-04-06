defmodule TdDq.Search.MockIndexWorker do
  @moduledoc false
  use Agent

  alias TdDq.Search.MockIndexWorker

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: MockIndexWorker)
  end

  def calls, do: Agent.get(MockIndexWorker, & &1)

  def clear, do: Agent.update(MockIndexWorker, fn _ -> [] end)

  def reindex do
    Agent.update(MockIndexWorker, &(&1 ++ [{:reindex}]))
  end

  def reindex_rules(param) do
    Agent.update(MockIndexWorker, &(&1 ++ [{:reindex_rules, param}]))
  end

  def reindex_implementations(param) do
    Agent.update(MockIndexWorker, &(&1 ++ [{:reindex_implementations, param}]))
  end

  def delete_rules(param) do
    Agent.update(MockIndexWorker, &(&1 ++ [{:delete_rules, param}]))
  end

  def delete_implementations(param) do
    Agent.update(MockIndexWorker, &(&1 ++ [{:delete_implementations, param}]))
  end

  def ping(param) do
    Agent.update(MockIndexWorker, &(&1 ++ [{:ping, param}]))
  end
end
