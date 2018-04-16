defmodule Mix.Tasks.Td.RunDb do
  use Mix.Task

  @shortdoc "Run postgres container"

  @moduledoc """
    Run postgres container. For linux. No sudo.
  """

  def run(args) do
    password = if length(args) == 1, do:  Enum.at(args, 0), else: "postgres"
    command_to_run = "docker run --name truebg-postgres -p 5432:5432 -e POSTGRES_PASSWORD=#{password} -d postgres:10.1"
    command_to_run_list = String.split(command_to_run, " ")
    [command|command_args] = command_to_run_list
    System.cmd(command, command_args)
  end

end
