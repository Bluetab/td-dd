defmodule TdDd.TaskSupervisor do
  @moduledoc """
  task supervisor
  """

  def await_completion(timeout \\ 1_000) do
    TdDd.TaskSupervisor
    |> Task.Supervisor.children()
    |> Enum.each(&Process.monitor/1)

    receive do
      {:DOWN, _ref, :process, _object, reason} -> reason
    after
      timeout -> :timeout
    end
  end
end
