defmodule TdDd.DataStructures.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures"

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with data structures
  def authorize(_action, %{role: "admin"}, _params), do: true

  # Service accounts can perform these actions on any data structure
  def authorize(action, %{role: "service"}, _params)
      when action in [
             :manage_confidential_structures,
             :query,
             :show,
             :update_data_structure,
             :upload,
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

  def authorize(:manage_structures_domain, %{} = claims, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :view_data_structure, domain_ids) and
      authorize(:manage_structures_domain, claims, domain_ids)
  end

  def authorize(:manage_structures_domain, %{} = claims, domain_ids) when is_list(domain_ids) do
    Enum.all?(domain_ids, &Permissions.authorized?(claims, :manage_structures_domain, &1))
  end

  def authorize(:view_data_structure, %{} = claims, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :view_data_structure, domain_ids)
  end

  def authorize(action, %{} = claims, %DataStructure{domain_ids: domain_ids})
      when action in [
             :create_grant_request,
             :create_foreign_grant_request,
             :delete_data_structure,
             :link_data_structure,
             :link_structure_to_structure,
             :manage_grants,
             :manage_grant_removal,
             :manage_foreign_grant_removal,
             :update_data_structure,
             :view_data_structures_profile,
             :view_grants,
             :view_protected_metadata
           ] do
    Permissions.authorized?(claims, :view_data_structure, domain_ids) and
      Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  # Match on non `DataStructure` struct to handle authorization from ElasticSearch
  def authorize(action, %{} = claims, %{domain_ids: domain_ids})
      when action in [
             :create_grant_request,
             :create_foreign_grant_request,
             :manage_grant_removal
           ] do
    Permissions.authorized?(claims, :view_data_structure, domain_ids) and
      Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  def authorize(:tag, %{} = claims, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def authorize(:update_data_structure, %{} = claims, %Changeset{} = changeset) do
    authorize(:update_domain_ids, claims, changeset) and
      authorize(:update_confidential, claims, changeset)
  end

  def authorize(:update_domain_ids, %{} = claims, %Changeset{data: structure} = changeset) do
    case Changeset.fetch_field(changeset, :domain_ids) do
      {:changes, domain_ids} ->
        authorize(:manage_structures_domain, claims, structure) and
          authorize(:manage_structures_domain, claims, domain_ids)

      _ ->
        true
    end
  end

  def authorize(:update_confidential, %{} = claims, %Changeset{data: structure} = changeset) do
    case Changeset.fetch_field(changeset, :confidential) do
      {:changes, _} -> authorize(:manage_confidential_structures, claims, structure)
      _ -> true
    end
  end

  def authorize(:upload, %{} = claims, domain_id)
      when is_binary(domain_id) or is_integer(domain_id) do
    Permissions.authorized?(claims, :manage_structures_metadata, domain_id)
  end

  def authorize(:query, %{} = claims, _query) do
    Permissions.authorized?(claims, :view_data_structure)
  end

  def authorize(_action, _claims, _params), do: false
end
