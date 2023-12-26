defmodule TdDd.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Profiles.Profile
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure
  alias TdDq.Rules.RuleResult

  def a <~> b, do: approximately_equal(a, b)
  def a <|> b, do: approximately_equal(sorted(a), sorted(b))

  ## Sort by id if present
  defp sorted([%{id: _} | _] = list) do
    Enum.sort_by(list, & &1.id)
  end

  defp sorted([%Hierarchy{} | _] = list) do
    Enum.sort_by(list, &{&1.dsv_id, &1.ancestor_dsv_id})
  end

  defp sorted(list), do: Enum.sort(list)

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%DataStructure{} = a, %DataStructure{} = b) do
    drop_fields = [
      :versions,
      :system,
      :domain,
      :linked_concepts,
      :published_note
    ]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  ## Equality test for data structure versions without comparing Ecto associations.
  defp approximately_equal(%DataStructureVersion{} = a, %DataStructureVersion{} = b) do
    drop_fields = [
      :children,
      :classes,
      :classifications,
      :data_structure,
      :external_id,
      :parents,
      :path,
      :with_profiling,
      :published_note,
      :structure_type
    ]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%StructureNote{} = a, %StructureNote{} = b) do
    Map.drop(a, [:data_structure]) == Map.drop(b, [:data_structure])
  end

  ## Equality test for rule implementation without comparing Ecto associations.
  defp approximately_equal(%Implementation{} = a, %Implementation{} = b) do
    Map.drop(a, [:rule]) == Map.drop(b, [:rule])
  end

  ## Equality test for rule implementation without comparing Ecto associations.
  defp approximately_equal(%ImplementationStructure{} = a, %ImplementationStructure{} = b) do
    drop_fields = [
      :implementation,
      :data_structure
    ]

    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  ## Equality test for rule result without comparing Ecto associations.
  defp approximately_equal(%RuleResult{} = a, %RuleResult{} = b) do
    Map.drop(a, [:implementation]) == Map.drop(b, [:implementation])
  end

  defp approximately_equal(%Grant{} = a, %Grant{} = b) do
    Map.drop(a, [:data_structure]) == Map.drop(b, [:data_structure])
  end

  defp approximately_equal(%GrantRequest{} = a, %GrantRequest{} = b) do
    drop_fields = [:data_structure, :group, :pending_roles, :approvals]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%GrantRequestGroup{} = a, %GrantRequestGroup{} = b) do
    Map.drop(a, [:requests]) == Map.drop(b, [:requests])
  end

  defp approximately_equal(%Profile{} = a, %Profile{} = b) do
    drop_fields = [:data_structure]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%Hierarchy{} = a, %Hierarchy{} = b) do
    test_fields = [:dsv_id, :ancestor_dsv_id, :ancestor_level]
    Map.take(a, test_fields) == Map.take(b, test_fields)
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(a, b), do: a == b
end
