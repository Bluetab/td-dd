defmodule TdDdWeb.Resolvers.ReferenceData do
  @moduledoc """
  Resolver for reference datasets.
  """

  alias TdDd.ReferenceData
  alias TdDd.ReferenceData.Policy

  def reference_datasets(_parent, _args, resolution) do
    permitted_domain_ids = Policy.view_permitted_domain_ids(claims(resolution))
    reference_datasets = %{domain_ids: permitted_domain_ids}
    |> ReferenceData.list()
    |> Enum.map(&filter_permitted_domains(&1, permitted_domain_ids))
    {:ok, reference_datasets}
  end

  def reference_dataset(_parent, %{id: id}, resolution) do
    user_claims = claims(resolution)
    permitted_domain_ids = Policy.view_permitted_domain_ids(user_claims)
    with dataset <- ReferenceData.get!(id),
         :ok <- Bodyguard.permit(ReferenceData, :show, user_claims, dataset) do
      {:ok, filter_permitted_domains(dataset, permitted_domain_ids)}
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

  defp filter_permitted_domains(reference_dataset, :all), do: reference_dataset

  defp filter_permitted_domains(%{domain_ids: domain_ids} = reference_dataset, permitted_domain_ids) do
    domain_ids = permitted_domain_ids
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(domain_ids))
    |> MapSet.to_list()
    Map.put(reference_dataset, :domain_ids, domain_ids)
  end
end
