defmodule TdDd.Canada.DataStructureAbilities do
  @moduledoc false
  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  def can?(%User{}, _action, %DataStructure{domain_id: nil}), do: false

  def can?(%User{} = user, :create_data_structure, domain_id) do
      Permissions.authorized?(user, :create_data_structure, domain_id)
  end

  def can?(%User{} = user, :delete_data_structure, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(user, :delete_data_structure, domain_id)
  end

  def can?(%User{} = user, :update_data_structure, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(user, :update_data_structure, domain_id)
  end

  def can?(%User{} = user, :view_data_structure, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(user, :view_data_structure, domain_id)
  end
end
