defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Auth.Claims

  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureTagAbilities
  alias TdDd.Canada.DataStructureTypeAbilities
  alias TdDd.Canada.DataStructureVersionAbilities
  alias TdDd.Canada.ExecutionAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.Canada.StructureNoteAbilities
  alias TdDd.Canada.SystemAbilities
  alias TdDd.Canada.UnitAbilities
  alias TdDd.Classifiers.Classifier
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Events.ProfileEvent
  alias TdDd.Executions.ProfileExecution
  alias TdDd.Executions.ProfileGroup
  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit
  alias TdDd.Systems.System

  defimpl Canada.Can, for: Claims do
    # service accounts can upload metadata and profiling
    def can?(%Claims{role: "service"}, :upload, _resource), do: true

    def can?(%Claims{}, _action, nil), do: false

    def can?(%Claims{} = claims, action, System) do
      SystemAbilities.can?(claims, action, System)
    end

    def can?(%Claims{} = claims, action, %System{} = system) do
      SystemAbilities.can?(claims, action, system)
    end

    def can?(%Claims{} = claims, action, %Classifier{} = classifier) do
      SystemAbilities.can?(claims, action, classifier)
    end

    def can?(%Claims{} = claims, action, target)
        when target in [ProfileEvent, ProfileExecution, ProfileGroup] do
      ExecutionAbilities.can?(claims, action, target)
    end

    def can?(%Claims{} = claims, action, %ProfileExecution{} = target) do
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

    def can?(%Claims{} = claims, action, {StructureNote, domain_id}) do
      StructureNoteAbilities.can?(claims, action, domain_id)
    end

    def can?(%Claims{} = claims, action, DataStructureTag) do
      DataStructureTagAbilities.can?(claims, action, DataStructureTag)
    end

    def can?(%Claims{} = claims, action, %DataStructureTag{} = data_structure_tag) do
      DataStructureTagAbilities.can?(claims, action, data_structure_tag)
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
