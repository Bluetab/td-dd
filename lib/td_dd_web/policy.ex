defmodule TdDdWeb.Policy do
  @moduledoc "Authorization rules for GraphQL API"

  @behaviour Bodyguard.Policy

  @implementation_mutations [
    :deprecate_implementation,
    :publish_implementation,
    :reject_implementation,
    :submit_implementation
  ]

  @tag_mutations [:tag_structure, :delete_structure_tag]

  # Extract claims from Absinthe Resolution context
  def authorize(action, %{context: %{claims: claims}} = _resolution, params) do
    authorize(action, claims, params)
  end

  # admin and service accounts can perform any GraphQL query
  def authorize(:query, %{role: "admin"}, _resource), do: true
  def authorize(:query, %{role: "service"}, _resource), do: true

  def authorize(:query, %{role: "user"}, :me), do: true
  def authorize(:query, %{role: "user"}, :domain), do: true
  def authorize(:query, %{role: "user"}, :domains), do: true
  def authorize(:query, %{role: "user"}, :templates), do: true
  def authorize(:query, %{role: "user"}, :structure_notes), do: true

  def authorize(:query, %{} = claims, :data_structure),
    do: Bodyguard.permit(TdDd.DataStructures, :query, claims)

  def authorize(:query, %{} = claims, :functions),
    do: Bodyguard.permit(TdDq.Functions, :query, claims)

  def authorize(:query, %{} = claims, :implementation),
    do: Bodyguard.permit(TdDq.Implementations, :query, claims)

  def authorize(:query, %{} = claims, :implementation_result),
    do: Bodyguard.permit(TdDq.Rules.RuleResults, :query, claims)

  def authorize(:query, %{} = claims, :latest_grant_request),
    do: Bodyguard.permit(TdDd.Grants, :query, claims, :latest_grant_request)

  def authorize(:query, %{} = claims, :reference_dataset),
    do: Bodyguard.permit(TdDd.ReferenceData, :query, claims, :reference_dataset)

  def authorize(:query, %{} = claims, :reference_datasets),
    do: Bodyguard.permit(TdDd.ReferenceData, :query, claims, :reference_datasets)

  def authorize(:query, %{} = claims, :sources),
    do: Bodyguard.permit(TdCx.Sources, :query, claims, :sources)

  def authorize(:query, %{} = claims, :tags),
    do: Bodyguard.permit(TdDd.DataStructures.Tags, :query, claims, :tags)

  def authorize(:query, _claims, _params), do: false

  # Mutations

  def authorize(:mutation, %{role: "admin"}, _mutation), do: true

  def authorize(:mutation, %{} = claims, mutation) when mutation in @tag_mutations,
    do: Bodyguard.permit(TdDd.DataStructures.Tags, :mutation, claims, mutation)

  def authorize(:mutation, %{} = claims, mutation) when mutation in @implementation_mutations,
    do: Bodyguard.permit(TdDq.Implementations, :mutation, claims, mutation)

  def authorize(:mutation, _claims, _params), do: false
end
