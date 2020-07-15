defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Accounts.User
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureTypeAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureType

  defimpl Canada.Can, for: User do
    # administrator is superpowerful
    def can?(%User{is_admin: true}, _action, _data_structure), do: true

    def can?(%User{}, _action, nil), do: false

    def can?(%User{} = user, action, %Link{} = link) do
      LinkAbilities.can?(user, action, link)
    end

    def can?(%User{} = user, :create_link, %{data_structure: data_structure}) do
      LinkAbilities.can?(user, :create_link, data_structure)
    end

    def can?(%User{} = _user, _action, Unit), do: false

    def can?(%User{} = user, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(user, action, data_structure)
    end

    def can?(%User{} = user, action, %{data_structure: data_structure}) do
      DataStructureAbilities.can?(user, action, data_structure)
    end

    def can?(%User{} = user, action, %DataStructureType{} = data_structure_type) do
      DataStructureTypeAbilities.can?(user, action, data_structure_type)
    end

    def can?(%User{} = user, action, domain_id) do
      DataStructureAbilities.can?(user, action, domain_id)
    end
  end
end
