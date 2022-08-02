defmodule TdDd.Canada.DataStructureAbilities do
  @moduledoc false
  alias Ecto.Changeset
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  # Admin accounts can do anything with data structures
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Service accounts can view any data structure
  def can?(%Claims{role: "service"}, :view_data_structure, _any), do: true
  def can?(%Claims{role: "service"}, :update_data_structure, _any), do: true
  def can?(%Claims{role: "service"}, :manage_confidential_structures, _any), do: true
  def can?(%Claims{role: "service"}, :manage_structures_domain, _any), do: false
  def can?(%Claims{role: "service"}, :view_data_structures_profile, _any), do: true
  def can?(%Claims{role: "service"}, :show, _any), do: true

  # Only admin and service roles can do anything on domainless structures
  def can?(%Claims{}, _action, %DataStructure{domain_ids: nil}), do: false
  def can?(%Claims{}, _action, %DataStructure{domain_ids: []}), do: false

  def can?(
        %Claims{} = claims,
        :manage_confidential_structures,
        %DataStructure{domain_ids: domain_ids}
      ) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_ids)
  end

  def can?(%Claims{} = claims, :list_bulk_update_events, DataStructure) do
    Permissions.authorized?(claims, :create_structure_note)
  end

  def can?(
        %Claims{} = claims,
        action,
        %DataStructure{confidential: true, domain_ids: domain_ids} = structure
      ) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_ids) and
      can?(claims, action, %{structure | confidential: false})
  end

  def can?(%Claims{} = claims, action, %DataStructure{domain_ids: domain_ids})
      when action in [:delete_data_structure, :update_data_structure, :view_data_structure] do
    Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  def can?(%Claims{} = claims, action, %DataStructure{domain_ids: domain_ids})
      when action in [
             :create_structure_note,
             :delete_structure_note,
             :deprecate_structure_note,
             :edit_structure_note,
             :publish_structure_note,
             :publish_structure_note_from_draft,
             :reject_structure_note,
             :send_structure_note_to_approval,
             :unreject_structure_note,
             :view_structure_note_history
             # :force_create_structure_note is not a permission (only admin can)
           ] do
    Permissions.authorized?(claims, :view_data_structure, domain_ids) and
      Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  def can?(%Claims{} = claims, :show, %DataStructure{} = data_structure) do
    can?(claims, :view_data_structure, data_structure)
  end

  def can?(
        %Claims{} = claims,
        :view_data_structures_profile,
        %DataStructure{domain_ids: domain_ids}
      ) do
    Permissions.authorized?(claims, :view_data_structures_profile, domain_ids)
  end

  def can?(%Claims{} = claims, :manage_structures_domain, %DataStructure{domain_ids: domain_ids}) do
    can?(claims, :manage_structures_domain, domain_ids)
  end

  def can?(%Claims{} = claims, :manage_structures_domain, domain_ids) do
    Enum.all?(domain_ids, &Permissions.authorized?(claims, :manage_structures_domain, &1))
  end

  def can?(%Claims{} = claims, :upload, domain_id) do
    Permissions.authorized?(claims, :manage_structures_metadata, domain_id)
  end

  def can?(%Claims{} = claims, :link_data_structure, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :link_data_structure, domain_ids)
  end

  def can?(%Claims{} = claims, :tag, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def can?(%Claims{} = claims, :untag, %DataStructure{
        domain_ids: domain_ids
      }) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def can?(%Claims{} = claims, :update_domain_ids, DataStructure) do
    Permissions.authorized?(claims, :manage_structures_domain)
  end

  def can?(%Claims{} = claims, :query, DataStructure) do
    Permissions.authorized?(claims, :view_data_structure)
  end

  def can?(%Claims{}, _action, %DataStructure{}), do: false

  def can?(%Claims{}, _action, DataStructure), do: false

  def can?(%Claims{} = claims, :update_data_structure, %Changeset{} = changeset) do
    can?(claims, :update_domain_ids, changeset) and
      can?(claims, :update_confidential, changeset)
  end

  def can?(%Claims{} = claims, :update_domain_ids, %Changeset{data: structure} = changeset) do
    case Changeset.fetch_field(changeset, :domain_ids) do
      {:changes, domain_ids} ->
        can?(claims, :manage_structures_domain, structure) and
          can?(claims, :manage_structures_domain, domain_ids)

      _ ->
        true
    end
  end

  def can?(%Claims{} = claims, :update_confidential, %Changeset{data: structure} = changeset) do
    case Changeset.fetch_field(changeset, :confidential) do
      {:changes, _} -> can?(claims, :manage_confidential_structures, structure)
      _ -> true
    end
  end

  def can?(_claims, _action, _resource) do
    false
  end
end
