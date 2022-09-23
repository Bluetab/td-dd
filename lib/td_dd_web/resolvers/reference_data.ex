defmodule TdDdWeb.Resolvers.ReferenceData do
  @moduledoc """
  Resolver for reference datasets.
  """

  alias TdDd.ReferenceData

  def reference_datasets(_parent, _args, resolution) do
    with :ok <- Bodyguard.permit(ReferenceData, :list, resolution) do
      {:ok, ReferenceData.list()}
    end
  end

  def reference_dataset(_parent, %{id: id}, resolution) do
    with :ok <- Bodyguard.permit(ReferenceData, :show, resolution),
         dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :show, resolution, dataset) do
      {:ok, dataset}
    end
  rescue
    _ -> {:error, :not_found}
  end

  def create_reference_dataset(_parent, %{dataset: args}, resolution) do
    with :ok <- Bodyguard.permit(ReferenceData, :mutate, resolution, :create_reference_dataset) do
      ReferenceData.create(args)
    end
  end

  def update_reference_dataset(_parent, %{dataset: %{id: id} = args}, resolution) do
    with :ok <- Bodyguard.permit(ReferenceData, :mutate, resolution, :update_reference_dataset),
         dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :update, resolution, dataset) do
      ReferenceData.update(dataset, args)
    end
  rescue
    _ -> {:error, :not_found}
  end

  def delete_reference_dataset(_parent, %{id: id}, resolution) do
    with :ok <- Bodyguard.permit(ReferenceData, :mutate, resolution, :delete_reference_dataset),
         dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :delete, resolution, dataset) do
      ReferenceData.delete(dataset)
    end
  rescue
    _ -> {:error, :not_found}
  end
end
