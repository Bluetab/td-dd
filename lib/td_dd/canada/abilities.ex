defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdDd.Accounts.User
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.DataStructures.DataStructure

  defimpl Canada.Can, for: User do

    def can?(%User{}, _action, nil),  do: false

    # administrator is superpowerful
    def can?(%User{is_admin: true}, _action, _data_structure)  do
      true
    end

    def can?(%User{} = user, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(user, action, data_structure)
    end

    def can?(%User{} = user, action, domain_id) do
      DataStructureAbilities.can?(user, action, domain_id)
    end
  end
end
