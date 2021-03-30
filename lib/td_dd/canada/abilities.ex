defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Auth.Claims

  alias TdDd.Canada.{
    DataStructureAbilities,
    DataStructureTypeAbilities,
    DataStructureVersionAbilities,
    ExecutionAbilities,
    LinkAbilities,
    UnitAbilities
  }

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Executions.{Execution, Group}
  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit

  defimpl Canada.Can, for: Claims do
    # service accounts can upload metadata and profiling
    def can?(%Claims{role: "service"}, :upload, _resource), do: true

    def can?(%Claims{}, _action, nil), do: false

    def can?(%Claims{} = claims, action, target) when target in [Execution, Group] do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %Execution{} = target) do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, :create_link, %{data_structure: data_structure}) do
      LinkAbilities.can?(claims, :create_link, data_structure)
    end

    def can?(%Claims{} = claims, action, Unit) do
      UnitAbilities.can?(claims, action, Unit)
    end

    def can?(%Claims{} = claims, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{} = claims, action, %DataStructureVersion{} = data_structure_version) do
      DataStructureVersionAbilities.can?(claims, action, data_structure_version)
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
