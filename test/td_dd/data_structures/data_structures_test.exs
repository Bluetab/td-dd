defmodule TdDd.DataStructuresTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  import TdDd.TestOperators

  setup _context do
    system = insert(:system, id: 1)
    {:ok, system: system}
  end

  describe "data_structures" do
    alias TdDd.DataStructures.DataStructure

    @valid_attrs %{
      "description" => "some description",
      "group" => "some group",
      "last_change_at" => "2010-04-17 14:00:00Z",
      "last_change_by" => 42,
      "name" => "some name",
      "external_id" => "some external_id",
      "metadata" => %{},
      "system_id" => 1
    }
    @update_attrs %{
      # description: "some updated description",
      df_content: %{updated: "content"}
    }
    @invalid_attrs %{
      description: nil,
      group: nil,
      last_change_at: nil,
      last_change_by: nil,
      name: nil
    }

    test "list_data_structures/1 returns all data_structures" do
      data_structure = insert(:data_structure)
      assert DataStructures.list_data_structures() <~> [data_structure]
    end

    test "list_data_structures/1 returns all data_structures from a search" do
      data_structure = insert(:data_structure)
      search_params = %{ou: [data_structure.ou]}

      assert DataStructures.list_data_structures(search_params), [data_structure]
    end

    test "get_data_structure!/1 returns the data_structure with given id" do
      data_structure = insert(:data_structure)
      assert DataStructures.get_data_structure!(data_structure.id) <~> data_structure
    end

    test "create_data_structure/1 with valid data creates a data_structure" do
      assert {:ok, %DataStructure{} = data_structure} =
               DataStructures.create_data_structure(@valid_attrs)

      assert data_structure.last_change_at ==
               DateTime.from_naive!(~N[2010-04-17 14:00:00Z], "Etc/UTC")

      assert data_structure.last_change_by == 42
      assert data_structure.system.external_id == "System_ref"
    end

    test "create_data_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_data_structure(@invalid_attrs)
    end

    test "update_data_structure/2 with valid data updates the data_structure" do
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure_id: data_structure.id)

      assert {:ok, data_structure} =
               DataStructures.update_data_structure(data_structure, @update_attrs)

      assert %DataStructure{} = data_structure
      assert data_structure.df_content == %{updated: "content"}
    end

    test "delete_data_structure/1 deletes the data_structure" do
      data_structure = insert(:data_structure)
      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(data_structure)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure!(data_structure.id)
      end
    end

    test "change_data_structure/1 returns a data_structure changeset" do
      data_structure = insert(:data_structure)
      assert %Ecto.Changeset{} = DataStructures.change_data_structure(data_structure)
    end
  end

  describe "data structure versions" do
    test "get_siblings/1 returns sibling structure versions" do
      [ds1, ds2, ds3, ds4] =
        1..4
        |> Enum.map(
          &insert(
            :data_structure,
            external_id: "DS#{&1}",
            system_id: 1
          )
        )

      [dsv1, dsv2, dsv3, dsv4] =
        [ds1, ds2, ds3, ds4]
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, name: &1.external_id)
        )

      [{dsv1, dsv2}, {dsv1, dsv3}, {dsv2, dsv4}, {dsv3, dsv4}]
      |> Enum.map(fn {parent, child} ->
        insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)
      end)

      assert DataStructures.get_siblings(dsv1) == []
      assert DataStructures.get_siblings(dsv2) <~> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv3) <~> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv4) <~> [dsv4]
    end

    test "delete_data_structure/1 deletes a data_structure with relations" do
      alias TdDd.DataStructures.DataStructure
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv2.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv3.id)

      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(ds1)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure!(ds1.id)
      end

      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end
  end
end
