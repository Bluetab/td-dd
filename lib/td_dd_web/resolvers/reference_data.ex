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
  rescue
    _ -> {:error, :not_found}
  end

  def create_reference_dataset(_parent, %{dataset: args}, _resolution) do
    ReferenceData.create(args)
  end

  def update_reference_dataset(_parent, %{dataset: %{id: id} = args}, _resolution) do
    id
    |> ReferenceData.get!()
    |> ReferenceData.update(args)
  rescue
    _e -> {:error, :not_found}
  end

  def delete_reference_dataset(_parent, %{id: id}, _resolution) do
    id
    |> ReferenceData.get!()
    |> ReferenceData.delete()
  rescue
    _ -> {:error, :not_found}
  end
end
