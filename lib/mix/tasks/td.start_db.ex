defmodule Mix.Tasks.Td.StartDb do
  use Mix.Task

  @shortdoc "Start postgres container"

  @moduledoc """
    Start postgres container. For linux. No sudo.
  """

  def run(_args) do
    command_to_run = "docker start truebg-postgres"
    command_to_run_list = String.split(command_to_run, " ")
    [command|command_args] = command_to_run_list
    System.cmd(command, command_args)
  end

end
