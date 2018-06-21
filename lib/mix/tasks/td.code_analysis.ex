defmodule Mix.Tasks.Td.CodeAnalysis do
  use Mix.Task
  alias Mix.Tasks.Compile
  alias Mix.Tasks.Credo
  alias Mix.Tasks.Release.Clean

  @shortdoc "Run code analysis"

  @moduledoc """
    Run code analysis.
  """

  def run(_args) do
    Clean.run([])
    Compile.run([])
    Credo.run(["--strict"])
  end

end
