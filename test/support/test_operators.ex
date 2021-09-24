defmodule TdDd.TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDq.Implementations.Implementation

  def a <~> b, do: approximately_equal(a, b)
  def a <|> b, do: approximately_equal(sorted(a), sorted(b))

  ## Sort by id if present
  defp sorted([%{id: _} | _] = list) do
    Enum.sort_by(list, & &1.id)
  end

  defp sorted(list), do: Enum.sort(list)

  ## Equality test for data structures without comparing Ecto associations.
  defp approximately_equal(%DataStructure{} = a, %DataStructure{} = b) do
    Map.drop(a, [
      :domain_parents,
      :versions,
      :system,
      :domain,
      :linked_concepts_count,
      :latest_note
    ]) ==
      Map.drop(b, [
        :domain_parents,
        :versions,
        :system,
        :domain,
        :linked_concepts_count,
        :latest_note
      ])
  end

  ## Equality test for data structure versions without comparing Ecto associations.
  defp approximately_equal(%DataStructureVersion{} = a, %DataStructureVersion{} = b) do
    Map.drop(a, [
      :children,
      :parents,
      :data_structure,
      :external_id,
      :path,
      :classifications,
      :classes,
      :latest_note,
      :with_profiling
    ]) ==
      Map.drop(b, [
        :children,
        :parents,
        :data_structure,
        :external_id,
        :path,
        :classifications,
        :classes,
        :latest_note,
        :with_profiling
      ])
  end

  defp approximately_equal(%StructureNote{} = a, %StructureNote{} = b) do
    Map.drop(a, [:data_structure]) == Map.drop(b, [:data_structure])
  end

  ## Equality test for rule implementation without comparing Ecto associations.
  defp approximately_equal(%Implementation{} = a, %Implementation{} = b) do
    Map.drop(a, [:rule]) == Map.drop(b, [:rule])
  end

  defp approximately_equal(%Grant{} = a, %Grant{} = b) do
    Map.drop(a, [:data_structure]) == Map.drop(b, [:data_structure])
  end

  defp approximately_equal(%GrantRequest{} = a, %GrantRequest{} = b) do
    drop_fields = [:data_structure, :group]
    Map.drop(a, drop_fields) == Map.drop(b, drop_fields)
  end

  defp approximately_equal(%GrantRequestGroup{} = a, %GrantRequestGroup{} = b) do
    Map.drop(a, [:requests]) == Map.drop(b, [:requests])
  end

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(a, b), do: a == b
end
