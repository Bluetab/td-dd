defmodule TdDd.DataStructures.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures"

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # Extract claims from Absinthe Resolution context
  def authorize(action, %{context: %{claims: claims}} = _resolution, params) do
    authorize(action, claims, params)
  end

  # Admin accounts can do anything with data structures
  def authorize(_action, %{role: "admin"}, _params), do: true

  # Service accounts can perform these actions on any data structure
  def authorize(action, %{role: "service"}, _params)
      when action in [
             :manage_confidential_structures,
             :show,
             :update_data_structure,
             :view_data_structure,
             :view_data_structures_profile
           ],
      do: true

  # Domainless structures can only be managed by admin or service
  def authorize(_action, %{}, %DataStructure{domain_ids: nil}), do: false
  def authorize(_action, %{}, %DataStructure{domain_ids: []}), do: false

  def authorize(
        :manage_confidential_structures,
        %{} = claims,
        %DataStructure{domain_ids: domain_ids}
      ) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_ids)
  end

  # Confidentiality for regular users
  def authorize(
        action,
        %{} = claims,
        %DataStructure{confidential: true, domain_ids: domain_ids} = ds
      ) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_ids) and
      authorize(action, claims, %{ds | confidential: false})
  end

  def authorize(action, %{} = claims, %DataStructure{domain_ids: domain_ids})
      when action in [
             :delete_data_structure,
             :update_data_structure,
             :view_data_structure
           ] do
    Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  def authorize(_action, _claims, _params), do: false
end
