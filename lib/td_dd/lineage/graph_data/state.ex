defmodule TdDd.Lineage.GraphData.State do
  @moduledoc """
  Struct for holding the state of the `TdDd.Lineage.GraphData` server.
  """

  defstruct contains: %Graph{}, depends: %Graph{}, roots: [], ts: DateTime.utc_now(), notify: nil
end
