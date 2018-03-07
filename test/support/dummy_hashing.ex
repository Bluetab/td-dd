defmodule TdDd.DummyHashing do
  @moduledoc false

  def dummy_checkpw, do: false
  def checkpw(p1, p2), do: p1 == p2
  def hashpwsalt(p), do: p

end
