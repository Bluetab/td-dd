defmodule TdDdWeb.Resolvers.ReferenceData do
  @moduledoc """
  Resolver for reference datasets.
  """

  alias TdDd.ReferenceData

  def reference_datasets(_parent, _args, _resolution) do
    {:ok, ReferenceData.list()}
  end

  def reference_dataset(_parent, %{id: id}, resolution) do
    with dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :show, claims(resolution), dataset) do
      {:ok, dataset}
    end
  rescue
    _ -> {:error, :not_found}
  end

  def create_reference_dataset(_parent, %{dataset: args}, _resolution) do
    ReferenceData.create(args)
  end

  def update_reference_dataset(_parent, %{dataset: %{id: id} = args}, resolution) do
    with dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :update, claims(resolution), dataset) do
      ReferenceData.update(dataset, args)
    end
  rescue
    _ -> {:error, :not_found}
  end

  def delete_reference_dataset(_parent, %{id: id}, resolution) do
    with dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :delete, claims(resolution), dataset) do
      ReferenceData.delete(dataset)
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
