defmodule TdDdWeb.Resolvers.Functions do
  @moduledoc """
  Absinthe resolvers for data quality functions
  """

  alias TdDq.Functions

  def functions(_parent, _args, _resolution) do
    {:ok, Functions.list_functions()}
  end
end
