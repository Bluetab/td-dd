defmodule TdDd.DataStructures.DataStructureTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructure

  describe "changeset/3" do
    test "ensures confidential or domain_ids is valid" do
      last_change_by = 123

      assert %{valid?: true, changes: changes} =
               DataStructure.changeset(%DataStructure{}, %{}, last_change_by)

      assert changes == %{}

      assert %{valid?: false, errors: [domain_ids: {"must be a non-empty list", []}]} =
               DataStructure.changeset(
                 %DataStructure{domain_ids: nil},
                 %{"domain_ids" => []},
                 last_change_by
               )

      assert %{valid?: true, changes: changes} =
               DataStructure.changeset(
                 %DataStructure{},
                 %{"domain_ids" => [1, 2, 3]},
                 last_change_by
               )

      assert Map.keys(changes) == [:domain_ids, :last_change_by]

      assert %{valid?: true, changes: changes} =
               DataStructure.changeset(
                 %DataStructure{},
                 %{"confidential" => false},
                 last_change_by
               )

      assert Map.keys(changes) == [:confidential, :last_change_by]
    end
  end

  describe "alias_changeset/3" do
    test "allows alias to be cast" do
      assert %{valid?: true, changes: changes} =
               DataStructure.alias_changeset(%DataStructure{}, "foo", 123)

      assert changes == %{alias: "foo", last_change_by: 123}

      assert %{valid?: true, changes: changes} =
               DataStructure.alias_changeset(%DataStructure{alias: "foo"}, "foo", 123)

      assert changes == %{}
    end
  end
end
