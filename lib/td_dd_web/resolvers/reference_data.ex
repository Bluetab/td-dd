defmodule TdDdWeb.Resolvers.ReferenceData do
  @moduledoc """
  Resolver for reference datasets.
  """

  alias TdDd.ReferenceData

  def reference_datasets(_parent, _args, _resolution) do
    {:ok, ReferenceData.list()}
  end

  def reference_dataset(_parent, %{id: id}, _resolution) do
    {:ok, ReferenceData.get!(id)}
  end
end
