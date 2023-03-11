defmodule TdDdWeb.Resolvers.Labels do
  @moduledoc """
  Absinthe resolvers for data structure link labels
  """

  alias TdDd.DataStructures.Labels

  def labels(_parent, _args, _resolution) do
    {:ok, Labels.list_labels()}
  end
end
