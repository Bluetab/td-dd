defmodule TdDq.Canada.Abilities do
  @moduledoc false

  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.DataStructures.DataStructure
  alias TdDq.Auth.Claims
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{} = claims, action, Implementation) do
      ImplementationAbilities.can?(claims, action, Implementation)
    end

    def can?(%Claims{} = claims, action, %Implementation{} = implementation) do
      ImplementationAbilities.can?(claims, action, implementation)
    end

    def can?(%Claims{} = claims, :execute, %{} = target) do
      ImplementationAbilities.can?(claims, :execute, target)
    end

    def can?(%Claims{} = claims, action, %Ecto.Changeset{data: %Implementation{}} = target) do
      ImplementationAbilities.can?(claims, action, target)
    end

    # admin can do anything (except some actions authorized by ImplementionAbilities)
    def can?(%Claims{role: "admin"}, _action, _domain) do
      true
    end

    def can?(%Claims{} = claims, :view_published_concept, domain_id) do
      Permissions.authorized?(claims, :view_published_business_concepts, domain_id)
    end

    def can?(%Claims{} = claims, action, %DataStructure{} = data_structure) do
      DataStructureAbilities.can?(claims, action, data_structure)
    end

    def can?(%Claims{}, _action, _entity), do: false
  end
end
