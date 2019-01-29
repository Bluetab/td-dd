defmodule TdDq.CustomSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(%{children: children, strategy: strategy}) do
    Supervisor.init(children, strategy: strategy)
  end
end
