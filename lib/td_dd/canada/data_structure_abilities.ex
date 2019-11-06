defmodule TdDd.Canada.DataStructureAbilities do
  @moduledoc false
  alias TdDd.Accounts.User
  alias TdDd.Permissions

  def can?(%User{}, _action, %{domain_id: nil}), do: false

  def can?(%User{} = user, :create, %{domain_id: domain_id}) do
    Permissions.authorized?(user, :create_data_structure, domain_id)
  end

  def can?(%User{} = user, :create, domain_id) do
    Permissions.authorized?(user, :create_data_structure, domain_id)
  end

  def can?(%User{} = user, :manage_confidential_structures, %{domain_id: domain_id}) do
    Permissions.authorized?(user, :manage_confidential_structures, domain_id)
  end

  def can?(%User{} = user, :delete, %{domain_id: domain_id, confidential: confidential}) do
    Permissions.authorized?(user, :delete_data_structure, domain_id) &&
    (!confidential || Permissions.authorized?(user, :manage_confidential_structures, domain_id))
  end

  def can?(%User{} = user, :update, %{domain_id: domain_id, confidential: confidential}) do
    Permissions.authorized?(user, :update_data_structure, domain_id) &&
    (!confidential || Permissions.authorized?(user, :manage_confidential_structures, domain_id))
  end

  def can?(%User{} = user, :view_data_structure, %{domain_id: domain_id, confidential: confidential}) do
    Permissions.authorized?(user, :view_data_structure, domain_id) &&
    (!confidential || Permissions.authorized?(user, :manage_confidential_structures, domain_id))
  end

  def can?(%User{} = user, :view_data_structure, domain_id) do
    Permissions.authorized?(user, :view_data_structure, domain_id)
  end

  def can?(%User{} = user, :show, %{domain_id: domain_id, confidential: confidential}) do
    Permissions.authorized?(user, :view_data_structure, domain_id) &&
    (!confidential || Permissions.authorized?(user, :manage_confidential_structures, domain_id))
  end

  def can?(%User{} = user, :show, domain_id) do
    Permissions.authorized?(user, :view_data_structure, domain_id)
  end

  def can?(%User{} = user, :view_data_structures_profile, %{domain_id: domain_id}) do
    Permissions.authorized?(user, :view_data_structures_profile, domain_id)
  end

  def can?(%User{} = user, :upload, %{domain_id: domain_id}) do
    Permissions.authorized?(user, :manage_structures_metadata, domain_id)
  end

  def can?(%User{} = user, :upload, domain_id) do
    Permissions.authorized?(user, :manage_structures_metadata, domain_id)
  end

  def can?(%User{}, _action, %{}), do: false

  def can?(%User{}, _action, _), do: false
end
