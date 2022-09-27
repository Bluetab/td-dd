defmodule TdDd.Canada.Abilities do
  @moduledoc false
  alias TdCache.Link
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.Canada.DataStructureVersionAbilities
  alias TdDd.Canada.LinkAbilities
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation

  defimpl Canada.Can, for: Claims do
    @implementation_mutations [
      :deprecate_implementation,
      :publish_implementation,
      :reject_implementation,
      :submit_implementation
    ]

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

    def can?(%Claims{role: "user"} = claims, :query, :implementation),
      do: ImplementationAbilities.can?(claims, :list, Implementation)

    def can?(%Claims{}, _action, nil), do: false

    def can?(%{} = claims, :mutation, mutation) when mutation in @implementation_mutations do
      ImplementationAbilities.can?(claims, :mutation, mutation)
    end

    def can?(%{role: role}, :mutation, _mutation), do: role == "admin"

    def can?(%Claims{} = claims, action, %Implementation{} = implementation) do
      ImplementationAbilities.can?(claims, action, implementation)
    end

    def can?(%Claims{} = claims, action, %Link{} = link) do
      LinkAbilities.can?(claims, action, link)
    end

    def can?(%Claims{} = claims, action, %DataStructureVersion{} = data_structure_version) do
      DataStructureVersionAbilities.can?(claims, action, data_structure_version)
    end

    def can?(%Claims{} = claims, action, domain_id) do
      # raise "#{action} #{domain_id}"
      DataStructureAbilities.can?(claims, action, domain_id)
    end
  end
end
