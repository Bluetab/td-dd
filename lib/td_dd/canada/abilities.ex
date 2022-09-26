defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureVersionAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.Canada.StructureTagAbilities
  alias TdDd.Canada.SystemAbilities
  alias TdDd.Canada.TagAbilities
  alias TdDd.Classifiers.Classifier
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.DataStructures.Tags.Tag
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
    def can?(%Claims{role: "user"}, :query, :me), do: true
    def can?(%Claims{role: "user"}, :query, :domains), do: true
    def can?(%Claims{role: "user"}, :query, :domain), do: true
    def can?(%Claims{role: "user"}, :query, :templates), do: true

    def can?(%Claims{role: "user"} = claims, :query, :tags),
      do: TagAbilities.can?(claims, :index, Tag)

    def can?(%Claims{role: "user"} = claims, :query, :implementation),
      do: ImplementationAbilities.can?(claims, :list, Implementation)

    def can?(%Claims{role: "user"} = claims, :query, :implementation_result),
      do: RuleResultAbilities.can?(claims, :view, RuleResult)

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

    def can?(%Claims{} = claims, action, System) do
      SystemAbilities.can?(claims, action, System)
    end

    def can?(%Claims{} = claims, action, %System{} = system) do
      SystemAbilities.can?(claims, action, system)
    end

    def can?(%Claims{} = claims, action, %Classifier{} = classifier) do
      SystemAbilities.can?(claims, action, classifier)
    end

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, action, %DataStructureVersion{} = data_structure_version) do
      DataStructureVersionAbilities.can?(claims, action, data_structure_version)
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

    def can?(%Claims{} = claims, action, domain_id) do
      # raise "#{action} #{domain_id}"
      DataStructureAbilities.can?(claims, action, domain_id)
    end
  end
end
