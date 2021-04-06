defmodule TdDd.Search.MockIndexWorker do
  @moduledoc false
  use Agent

  alias TdDd.Search.MockIndexWorker

  def start_link(_) do
    Agent.start_link(fn -> 0 end, name: MockIndexWorker)
  end

  def reindex_count, do: Agent.get(MockIndexWorker, & &1)

  def reindex(_) do
    Agent.update(MockIndexWorker, &(&1 + 1))
  end
end
