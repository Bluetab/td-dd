defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdCx.Canada.SourceAbilities
  alias TdCx.Sources.Source
  alias TdDd.Auth.Claims
  alias TdDd.Canada.AccessAbilities
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureTypeAbilities
  alias TdDd.Canada.DataStructureVersionAbilities
  alias TdDd.Canada.ExecutionAbilities
  alias TdDd.Canada.GrantAbilities
  alias TdDd.Canada.LineageAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.Canada.ReferenceDataAbilities
  alias TdDd.Canada.StructureNoteAbilities
  alias TdDd.Canada.StructureTagAbilities
  alias TdDd.Canada.SystemAbilities
  alias TdDd.Canada.TagAbilities
  alias TdDd.Canada.UnitAbilities
  alias TdDd.Classifiers.Classifier
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Executions.ProfileEvent
  alias TdDd.Executions.ProfileExecution
  alias TdDd.Executions.ProfileGroup
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit
  alias TdDd.Profiles.Profile
  alias TdDd.ReferenceData.Dataset, as: ReferenceDataset
  alias TdDd.Systems.System
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Canada.RuleResultAbilities
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.RuleResult

  defimpl Canada.Can, for: Claims do
    @implementation_mutations [
      :deprecate_implementation,
      :publish_implementation,
      :reject_implementation,
      :submit_implementation
    ]

    @structure_tag_mutations [:tag_structure, :delete_structure_tag]

    # service accounts can upload metadata and profiling
    def can?(%Claims{role: "service"}, :upload, _resource), do: true

    # service and admin accounts can perform GraphQL queries
    def can?(%Claims{role: "service"}, :query, _resource), do: true
    def can?(%Claims{role: "admin"}, :query, _resource), do: true

    # GraphQL queries for regular users
    def can?(%Claims{role: "user"}, :query, :domains), do: true
    def can?(%Claims{role: "user"}, :query, :templates), do: true

    def can?(%Claims{role: "user"} = claims, :query, :sources),
      do: SourceAbilities.can?(claims, :list, Source)

    def can?(%Claims{role: "user"} = claims, :query, :tags),
      do: TagAbilities.can?(claims, :index, Tag)

    def can?(%Claims{role: "user"} = claims, :query, :data_structure),
      do: DataStructureAbilities.can?(claims, :query, DataStructure)

    def can?(%Claims{role: "user"} = claims, :query, :implementation),
      do: ImplementationAbilities.can?(claims, :list, Implementation)

    def can?(%Claims{role: "user"} = claims, :query, :implementation_result),
      do: RuleResultAbilities.can?(claims, :view, RuleResult)

    def can?(%Claims{role: "user"} = claims, :query, :reference_dataset),
      do: ReferenceDataAbilities.can?(claims, :show, ReferenceDataset)

    def can?(%Claims{role: "user"} = claims, :query, :reference_datasets),
      do: ReferenceDataAbilities.can?(claims, :list, ReferenceDataset)

    def can?(%Claims{}, _action, nil), do: false

    def can?(%{} = claims, :mutation, mutation) when mutation in @implementation_mutations do
      ImplementationAbilities.can?(claims, :mutation, mutation)
    end

    def can?(%{} = claims, :mutation, mutation) when mutation in @structure_tag_mutations do
      StructureTagAbilities.can?(claims, :mutation, mutation)
    end

    def can?(%{role: role}, :mutation, _mutation), do: role == "admin"

    def can?(%Claims{} = claims, action, %Implementation{} = implementation) do
      ImplementationAbilities.can?(claims, action, implementation)
    end

    def can?(%Claims{} = claims, action, %RuleResult{} = ruleResult) do
      RuleResultAbilities.can?(claims, action, ruleResult)
    end

    def can?(%Claims{} = claims, action, ReferenceDataset) do
      ReferenceDataAbilities.can?(claims, action, ReferenceDataset)
    end

    def can?(%Claims{} = claims, action, %ReferenceDataset{} = resource) do
      ReferenceDataAbilities.can?(claims, action, resource)
    end

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

    def can?(%Claims{role: "service"}, :index, Profile), do: true

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, :create_link, %{data_structure: data_structure}) do
      LinkAbilities.can?(claims, :create_link, data_structure)
    end

    def can?(%Claims{} = claims, action, Unit) do
      UnitAbilities.can?(claims, action, Unit)
    end

    def can?(%Claims{} = claims, action, Access) do
      AccessAbilities.can?(claims, action, Access)
    end

    def can?(%Claims{} = claims, action, %{hint: :domain} = domain) do
      UnitAbilities.can?(claims, action, domain)
    end

    def can?(%Claims{} = claims, action, LineageEvent) do
      LineageAbilities.can?(claims, action, LineageEvent)
    end

    def can?(%Claims{} = claims, :view_grants, %DataStructure{} = data_structure) do
      GrantAbilities.can?(claims, :view_grants, data_structure)
    end

    def can?(%Claims{} = claims, :create_grant, %DataStructure{} = data_structure) do
      GrantAbilities.can?(claims, :create_grant, data_structure)
    end

    def can?(%Claims{} = claims, action, %Grant{} = grant) do
      GrantAbilities.can?(claims, action, grant)
    end

    def can?(%Claims{} = claims, action, GrantRequest) do
      GrantAbilities.can?(claims, action, GrantRequest)
    end

    def can?(%Claims{} = claims, action, %GrantRequest{} = target) do
      GrantAbilities.can?(claims, action, target)
    end

    def can?(%Claims{role: "admin"}, :update_grant_removal, %DataStructure{}), do: true

    def can?(%Claims{} = claims, :update_grant_removal, %DataStructure{domain_ids: domain_ids}) do
      GrantAbilities.can?(claims, :update_pending_removal, domain_ids)
    end

    def can?(%Claims{role: "admin"}, :create_grant_request, %DataStructure{}), do: true

    def can?(%Claims{} = claims, :create_grant_request, %DataStructure{domain_ids: domain_ids}) do
      GrantAbilities.can?(claims, :create_grant_request, domain_ids)
    end

    def can?(%Claims{role: "admin"}, :create_grant_request_group, %DataStructure{}), do: true

    def can?(%Claims{} = claims, :create_grant_request_group, params) do
      GrantAbilities.can?(claims, :create_grant_request_group, params)
    end

    def can?(%Claims{} = claims, action, %GrantRequestGroup{} = group) do
      GrantAbilities.can?(claims, action, group)
    end

    def can?(%Claims{} = claims, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{} = claims, :update_data_structure, %{} = changeset) do
      DataStructureAbilities.can?(claims, :update_data_structure, changeset)
    end

    def can?(%Claims{} = claims, action, %DataStructureVersion{} = data_structure_version) do
      DataStructureVersionAbilities.can?(claims, action, data_structure_version)
    end

    def can?(%Claims{} = claims, action, :structure_notes) do
      StructureNoteAbilities.can?(claims, action, :structure_notes)
    end

    def can?(%Claims{} = claims, action, StructureNote) do
      StructureNoteAbilities.can?(claims, action, StructureNote)
    end

    def can?(%Claims{} = claims, action, Tag) do
      TagAbilities.can?(claims, action, Tag)
    end

    def can?(%Claims{} = claims, action, %Tag{} = tag) do
      TagAbilities.can?(claims, action, tag)
    end

    def can?(%Claims{} = claims, action, %StructureTag{} = structure_tag) do
      StructureTagAbilities.can?(claims, action, structure_tag)
    end

    def can?(%Claims{} = claims, action, %DataStructureType{} = data_structure_type) do
      DataStructureTypeAbilities.can?(claims, action, data_structure_type)
    end

    def can?(%Claims{} = claims, action, %Node{} = node) do
      UnitAbilities.can?(claims, action, node)
    end

    def can?(%Claims{} = claims, action, DataStructure) do
      DataStructureAbilities.can?(claims, action, DataStructure)
    end

    def can?(%Claims{} = claims, action, domain_id) do
      DataStructureAbilities.can?(claims, action, domain_id)
    end
  end
end
