defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureTypeAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.Canada.UnitAbilities
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.Lineage.Units.Node

  defimpl Canada.Can, for: Claims do
    # administrator is superpowerful
    def can?(%Claims{is_admin: true}, _action, _data_structure), do: true

    def can?(%Claims{}, _action, nil), do: false

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, :create_link, %{data_structure: data_structure}) do
      LinkAbilities.can?(claims, :create_link, data_structure)
    end

    def can?(%Claims{}, _action, Unit), do: false

    def can?(%Claims{} = claims, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{} = claims, action, %{data_structure: data_structure}) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{} = claims, action, %DataStructureType{} = data_structure_type) do
      DataStructureTypeAbilities.can?(claims, action, data_structure_type)
    end

    def can?(%Claims{} = claims, action, %Node{} = node) do
      UnitAbilities.can?(claims, action, node)
    end

    def can?(%Claims{} = claims, action, domain_id) do
      DataStructureAbilities.can?(claims, action, domain_id)
    end
  end
end
