defmodule TdDd.ProcessCase do
  @moduledoc """
  Setup for tests requiring waiting for async result
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      # function that returns the function to be injected
      def notify_callback do
        pid = self()

        fn reason, msg ->
          # send msg back to test process
          Kernel.send(pid, {reason, msg})
          :ok
        end
      end
    end
  end
end
