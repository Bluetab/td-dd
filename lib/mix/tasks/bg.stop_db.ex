defmodule Mix.Tasks.Bg.StopDb do
  use Mix.Task

  @shortdoc "Stop postgres container"

  @moduledoc """
    Stop postgres container. For linux. No sudo.
  """

  def run(_args) do
    command_to_run = "docker stop truebg-postgres"
    command_to_run_list = String.split(command_to_run, " ")
    [command|command_args] = command_to_run_list
    System.cmd(command, command_args)
  end

end
