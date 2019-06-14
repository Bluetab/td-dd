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
      description: "some description",
      group: "some group",
      last_change_at: "2010-04-17 14:00:00Z",
      last_change_by: 42,
      name: "some name",
      metadata: %{},
      system_id: 1
    }
    @update_attrs %{description: "some updated description", df_content: %{updated: "content"}}
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

    test "list_data_structures/1 returns all data_structures form a search" do
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

      assert data_structure.description == "some description"
      assert data_structure.group == "some group"

      assert data_structure.last_change_at ==
               DateTime.from_naive!(~N[2010-04-17 14:00:00Z], "Etc/UTC")

      assert data_structure.last_change_by == 42
      assert data_structure.name == "some name"
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
      assert data_structure.description == "some description"
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

  describe "data_fields" do
    alias TdDd.DataStructures.DataField

    @valid_attrs %{
      description: "some description",
      last_change_at: "2010-04-17 14:00:00Z",
      last_change_by: 42,
      name: "some name",
      nullable: true,
      precision: "some precision",
      type: "some type",
      metadata: %{}
    }
    @update_attrs %{
      description: "some updated description",
      last_change_at: "2011-05-18 15:01:01Z",
      last_change_by: 43,
      name: "some updated name",
      nullable: false,
      precision: "some updated precision",
      type: "some updated type"
    }
    @invalid_attrs %{
      description: nil,
      last_change_at: nil,
      last_change_by: nil,
      name: nil,
      nullable: nil,
      precision: nil,
      type: nil
    }

    test "list_data_fields/0 returns all data_fields" do
      data_field = insert(:data_field)
      assert DataStructures.list_data_fields() == [data_field]
    end

    test "get_data_field!/1 returns the data_field with given id" do
      data_field = insert(:data_field)
      assert DataStructures.get_data_field!(data_field.id) == data_field
    end

    test "create_data_field/1 with valid data creates a data_field" do
      data_structure = insert(:data_structure)

      data_structure_version =
        insert(:data_structure_version, data_structure_id: data_structure.id)

      creation_attrs =
        Map.put(@valid_attrs, :data_structure_version_id, data_structure_version.id)

      assert {:ok, %DataField{} = data_field} = DataStructures.create_data_field(creation_attrs)
      assert data_field.description == "some description"

      assert data_field.last_change_at ==
               DateTime.from_naive!(~N[2010-04-17 14:00:00Z], "Etc/UTC")

      assert data_field.last_change_by == 42
      assert data_field.name == "some name"
      assert data_field.nullable == true
      assert data_field.precision == "some precision"
      assert data_field.type == "some type"
    end

    test "create_data_field/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_data_field(@invalid_attrs)
    end

    test "update_data_field/2 with valid data updates the data_field" do
      data_field = insert(:data_field)
      assert {:ok, data_field} = DataStructures.update_data_field(data_field, @update_attrs)
      assert %DataField{} = data_field
      assert data_field.description == "some updated description"
    end

    test "delete_data_field/1 deletes the data_field" do
      data_field = insert(:data_field)
      assert {:ok, %DataField{}} = DataStructures.delete_data_field(data_field)
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_field!(data_field.id) end
    end

    test "change_data_field/1 returns a data_field changeset" do
      data_field = insert(:data_field)
      assert %Ecto.Changeset{} = DataStructures.change_data_field(data_field)
    end

    test "get_data_structure_with_fields!/1 returns the data_structure with given id and fields" do
      data_structure_parent = insert(:data_structure, name: "parent")
      name = Map.get(@valid_attrs, :name)
      data_structure_child = insert(:data_structure, name: name, class: "field")

      data_structure_version_parent =
        insert(:data_structure_version, data_structure_id: data_structure_parent.id)

      data_structure_version_child =
        insert(:data_structure_version, data_structure_id: data_structure_child.id)

      insert(:data_structure_relation,
        parent_id: data_structure_version_parent.id,
        child_id: data_structure_version_child.id
      )

      insert(
        :data_field,
        Map.put(@valid_attrs, :data_structure_versions, [data_structure_version_parent])
      )

      ds = DataStructures.get_data_structure_with_fields!(data_structure_parent.id)
      assert ds <~> data_structure_parent
      df = Enum.find(ds.data_fields, &(&1.name == name))
      assert df.field_structure_id == data_structure_child.id
    end

    test "get_data_structure_with_fields!/1 returns the data_structure with has_df_content" do
      data_structure_parent = insert(:data_structure, name: "parent")
      name = Map.get(@valid_attrs, :name)
      data_structure_child = insert(:data_structure, name: name, class: "field")

      data_structure_version_parent =
        insert(:data_structure_version, data_structure_id: data_structure_parent.id)

      data_structure_version_child =
        insert(:data_structure_version, data_structure_id: data_structure_child.id)

      insert(:data_structure_relation,
        parent_id: data_structure_version_parent.id,
        child_id: data_structure_version_child.id
      )

      insert(
        :data_field,
        Map.put(@valid_attrs, :data_structure_versions, [data_structure_version_parent])
      )

      ds = DataStructures.get_data_structure_with_fields!(data_structure_parent.id)
      assert ds <~> data_structure_parent
      df = Enum.find(ds.data_fields, &(&1.name == name))
      assert df.has_df_content == false
    end

    test "get_data_structure_with_fields!/1 returns the data_structure with has_df_content with content" do
      data_structure_parent = insert(:data_structure, name: "parent")
      name = Map.get(@valid_attrs, :name)

      data_structure_child =
        insert(:data_structure, name: name, class: "field", df_content: %{has: "value"})

      data_structure_version_parent =
        insert(:data_structure_version, data_structure_id: data_structure_parent.id)

      data_structure_version_child =
        insert(:data_structure_version, data_structure_id: data_structure_child.id)

      insert(:data_structure_relation,
        parent_id: data_structure_version_parent.id,
        child_id: data_structure_version_child.id
      )

      insert(
        :data_field,
        Map.put(@valid_attrs, :data_structure_versions, [data_structure_version_parent])
      )

      ds = DataStructures.get_data_structure_with_fields!(data_structure_parent.id)
      assert ds <~> data_structure_parent
      df = Enum.find(ds.data_fields, &(&1.name == name))
      assert df.has_df_content == true
    end
  end

  describe "data structure versions" do
    test "list_data_structure_versions/1 returns data structure versions" do
      data_structure = insert(:data_structure)

      data_structure_version =
        insert(:data_structure_version, data_structure_id: data_structure.id)

      data_structure_versions = DataStructures.list_data_structure_versions(data_structure.id)
      assert length(data_structure_versions) == 1
      assert data_structure_versions |> Enum.at(0) |> Map.get(:id) == data_structure_version.id
    end

    test "get_version_children/1 returns child versions" do
      ds1 = insert(:data_structure, id: 1, name: "DS1")
      ds2 = insert(:data_structure, id: 2, name: "DS2")
      ds3 = insert(:data_structure, id: 3, name: "DS3")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)

      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv2.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv3.id)
      children = DataStructures.get_version_children(dsv1.id)
      assert children <~> [dsv2, dsv3]
    end

    test "get_version_parents/1 returns parent versions" do
      ds1 = insert(:data_structure, id: 4, name: "DS4")
      ds2 = insert(:data_structure, id: 5, name: "DS5")
      ds3 = insert(:data_structure, id: 6, name: "DS6")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)

      insert(:data_structure_relation, child_id: dsv1.id, parent_id: dsv2.id)
      insert(:data_structure_relation, child_id: dsv1.id, parent_id: dsv3.id)

      parents = DataStructures.get_version_parents(dsv1.id)
      assert parents <~> [dsv2, dsv3]
    end

    test "get_siblings/1 returns sibling structures" do
      [ds1, ds2, ds3, ds4] =
        [7, 8, 9, 10]
        |> Enum.map(
          &insert(
            :data_structure,
            id: &1,
            name: "DS#{&1}",
            system_id: 1
          )
        )

      [dsv1, dsv2, dsv3, dsv4] =
        [ds1, ds2, ds3, ds4]
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      [{dsv1, dsv2}, {dsv1, dsv3}, {dsv2, dsv4}, {dsv3, dsv4}]
      |> Enum.map(fn {parent, child} ->
        insert(:data_structure_relation, parent_id: parent.id, child_id: child.id)
      end)

      [s1, s2, s3, s4] =
        [dsv1, dsv2, dsv3, dsv4]
        |> Enum.map(&DataStructures.get_siblings/1)

      assert s1 == []
      assert s2 <~> [ds2, ds3]
      assert s3 <~> [ds2, ds3]
      assert s4 <~> [ds4]
    end

    test "list_data_structures_with_no_parents/1 gets data_structures with no parents" do
      insert(:system, id: 4, external_id: "id4")
      insert(:system, id: 5, external_id: "id5")
      ds1 = insert(:data_structure, id: 51, name: "DS51", system_id: 4)
      ds2 = insert(:data_structure, id: 52, name: "DS52", system_id: 4)
      ds3 = insert(:data_structure, id: 53, name: "DS53", system_id: 4)
      ds4 = insert(:data_structure, id: 55, name: "DS54", system_id: 5)
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)
      insert(:data_structure_version, data_structure_id: ds4.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv2.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv3.id)

      assert [%{id: 51}] =
               DataStructures.list_data_structures_with_no_parents(%{"system_id" => 4})
    end

    test "list_data_structures_with_no_parents/1 filters field class data_structures" do
      insert(:system, id: 4, external_id: "id4")
      insert(:system, id: 5, external_id: "id5")
      ds1 = insert(:data_structure, id: 51, name: "DS51", system_id: 4, class: "field")
      ds2 = insert(:data_structure, id: 52, name: "DS52", system_id: 4)
      ds3 = insert(:data_structure, id: 53, name: "DS53", system_id: 4)
      ds4 = insert(:data_structure, id: 55, name: "DS54", system_id: 5)
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)
      insert(:data_structure_version, data_structure_id: ds4.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv2.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv3.id)

      assert [] == DataStructures.list_data_structures_with_no_parents(%{"system_id" => 4})
    end

    test "delete_data_structure/1 deletes a data_structure with relations" do
      alias TdDd.DataStructures.DataStructure
      ds1 = insert(:data_structure, id: 51, name: "DS51")
      ds2 = insert(:data_structure, id: 52, name: "DS52")
      ds3 = insert(:data_structure, id: 53, name: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)

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
