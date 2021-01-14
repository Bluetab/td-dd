defmodule TdDd.Canada.DataStructureAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  def can?(%Claims{}, _action, %DataStructure{domain_id: nil}), do: false

  def can?(%Claims{} = claims, :manage_confidential_structures, %DataStructure{
        domain_id: domain_id
      }) do
    Permissions.authorized?(claims, :manage_confidential_structures, domain_id)
  end

  def can?(%Claims{} = claims, :delete_data_structure, %DataStructure{
        domain_id: domain_id,
        confidential: confidential
      }) do
    Permissions.authorized?(claims, :delete_data_structure, domain_id) &&
      (!confidential ||
         Permissions.authorized?(claims, :manage_confidential_structures, domain_id))
  end

  def can?(%Claims{} = claims, :update_data_structure, %DataStructure{
        domain_id: domain_id,
        confidential: confidential
      }) do
    Permissions.authorized?(claims, :update_data_structure, domain_id) &&
      (!confidential ||
         Permissions.authorized?(claims, :manage_confidential_structures, domain_id))
  end

  def can?(%Claims{} = claims, :view_data_structure, %DataStructure{
        domain_id: domain_id,
        confidential: confidential
      }) do
    Permissions.authorized?(claims, :view_data_structure, domain_id) &&
      (!confidential ||
         Permissions.authorized?(claims, :manage_confidential_structures, domain_id))
  end

  def can?(%Claims{} = claims, :view_data_structure, domain_id) do
    Permissions.authorized?(claims, :view_data_structure, domain_id)
  end

  def can?(%Claims{} = claims, :show, %DataStructure{
        domain_id: domain_id,
        confidential: confidential
      }) do
    Permissions.authorized?(claims, :view_data_structure, domain_id) &&
      (!confidential ||
         Permissions.authorized?(claims, :manage_confidential_structures, domain_id))
  end

  def can?(%Claims{} = claims, :show, domain_id) do
    Permissions.authorized?(claims, :view_data_structure, domain_id)
  end

  def can?(%Claims{} = claims, :view_data_structures_profile, %DataStructure{
        domain_id: domain_id
      }) do
    Permissions.authorized?(claims, :view_data_structures_profile, domain_id)
  end

  def can?(%Claims{} = claims, :upload, domain_id) do
    Permissions.authorized?(claims, :manage_structures_metadata, domain_id)
  end

  def can?(%Claims{}, _action, %DataStructure{}), do: false

  def can?(%Claims{}, _action, DataStructure), do: false
end
