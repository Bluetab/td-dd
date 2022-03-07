defmodule TdDd.Canada.DataStructureAbilities do
  @moduledoc false
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

  def can?(%Claims{}, _action, %DataStructure{domain_id: nil}), do: false

  def can?(%Claims{} = claims, :manage_confidential_structures, %DataStructure{
        domain_id: domain_id
      }) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_id)
  end

  def can?(%Claims{} = claims, permission, %DataStructure{
        domain_id: domain_id,
        confidential: true
      })
      when permission in [:delete_data_structure, :update_data_structure, :view_data_structure] do
    Permissions.authorized?(claims, permission, domain_id) &&
      Permissions.authorized?(claims, :manage_confidential_structures, domain_id)
  end

  def can?(%Claims{} = claims, permission, %DataStructure{domain_id: domain_id})
      when permission in [:delete_data_structure, :update_data_structure, :view_data_structure] do
    Permissions.authorized?(claims, permission, domain_id)
  end

  def can?(%Claims{} = claims, :view_data_structure, domain_id) do
    Permissions.authorized?(claims, :view_data_structure, domain_id)
  end

  def can?(%Claims{} = claims, :show, %DataStructure{} = data_structure) do
    can?(claims, :view_data_structure, data_structure)
  end

  def can?(%Claims{} = claims, :show, domain_id) do
    Permissions.authorized?(claims, :view_data_structure, domain_id)
  end

  def can?(%Claims{} = claims, :view_data_structures_profile, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(claims, :view_data_structures_profile, domain_id)
  end

  def can?(%Claims{} = claims, :manage_structures_domain, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_structures_domain, domain_id)
  end

  def can?(%Claims{} = claims, :manage_structures_domain, domain_id) do
    Permissions.authorized?(claims, :manage_structures_domain, domain_id)
  end

  def can?(%Claims{} = claims, :upload, domain_id) do
    Permissions.authorized?(claims, :manage_structures_metadata, domain_id)
  end

  def can?(%Claims{} = claims, :link_data_structure_tag, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_id)
  end

  def can?(%Claims{} = claims, :delete_link_data_structure_tag, %DataStructure{
        domain_id: domain_id
      }) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_id)
  end

  def can?(%Claims{}, _action, %DataStructure{}), do: false

  def can?(%Claims{}, _action, DataStructure), do: false

  def can?(_claims, _action, _resource) do
    false
  end
end
