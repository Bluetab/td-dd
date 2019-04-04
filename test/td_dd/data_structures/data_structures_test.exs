defmodule TdDd.DataStructuresTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  import TdDd.TestOperators

  describe "data_structures" do
    alias TdDd.DataStructures.DataStructure

    @valid_attrs %{
      description: "some description",
      group: "some group",
      last_change_at: "2010-04-17 14:00:00Z",
      last_change_by: 42,
      name: "some name",
      metadata: %{}
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

    test "get_data_structure_with_fields!/1 returns the data_structure with given id and fields" do
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure_id: data_structure.id)

      assert DataStructures.get_data_structure_with_fields!(data_structure.id) <~> data_structure
      # TODO: Need to check fields...
    end

    test "create_data_structure/1 with valid data creates a data_structure" do
      system = insert(:system)
      valid_attrs = Map.merge(@valid_attrs, %{system_id: system.id})

      assert {:ok, %DataStructure{} = data_structure} =
               DataStructures.create_data_structure(valid_attrs)

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
      business_concept_id: "42",
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
      business_concept_id: "43",
      description: "some updated description",
      last_change_at: "2011-05-18 15:01:01Z",
      last_change_by: 43,
      name: "some updated name",
      nullable: false,
      precision: "some updated precision",
      type: "some updated type"
    }
    @invalid_attrs %{
      business_concept_id: nil,
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
      assert data_field.business_concept_id == "42"
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
      sys1 = insert(:system, name: "Sys1", external_id: "Ref 1")
      sys2 = insert(:system, name: "Sys2", external_id: "Ref 2")
      sys3 = insert(:system, name: "Sys3", external_id: "Ref 3")
      ds1 = insert(:data_structure, id: 1, name: "DS1", system: sys1)
      ds2 = insert(:data_structure, id: 2, name: "DS2", system: sys2)
      ds3 = insert(:data_structure, id: 3, name: "DS3", system: sys3)
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)

      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv2.id)
      insert(:data_structure_relation, parent_id: dsv1.id, child_id: dsv3.id)
      children = DataStructures.get_version_children(dsv1.id)
      assert children <~> [dsv2, dsv3]
    end

    test "get_version_parents/1 returns parent versions" do
      sys1 = insert(:system, name: "Sys1", external_id: "Ref 1")
      sys2 = insert(:system, name: "Sys2", external_id: "Ref 2")
      sys3 = insert(:system, name: "Sys3", external_id: "Ref 3")
      ds1 = insert(:data_structure, id: 4, name: "DS4", system: sys1)
      ds2 = insert(:data_structure, id: 5, name: "DS5", system: sys2)
      ds3 = insert(:data_structure, id: 6, name: "DS6", system: sys3)
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id)

      insert(:data_structure_relation, child_id: dsv1.id, parent_id: dsv2.id)
      insert(:data_structure_relation, child_id: dsv1.id, parent_id: dsv3.id)

      parents = DataStructures.get_version_parents(dsv1.id)
      assert parents <~> [dsv2, dsv3]
    end

    test "get_siblings/1 returns sibling structures" do
      systems =
        [7, 8, 9, 10]
        |> Enum.map(&insert(:system, id: &1, external_id: "SYS#{&1}"))

      [ds1, ds2, ds3, ds4] =
        [7, 8, 9, 10]
        |> Enum.map(
          &insert(
            :data_structure,
            id: &1,
            name: "DS#{&1}",
            system: Enum.find(systems, fn sys -> &1 == sys end)
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
  end

  describe "systems" do
    alias TdDd.DataStructures.System

    @valid_attrs %{external_id: "some external_id", name: "some name"}
    @update_attrs %{external_id: "some updated external_id", name: "some updated name"}
    @invalid_attrs %{external_id: nil, name: nil}

    def system_fixture(attrs \\ %{}) do
      {:ok, system} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DataStructures.create_system()

      system
    end

    test "list_systems/0 returns all systems" do
      system = system_fixture()
      assert DataStructures.list_systems() == [system]
    end

    test "get_system!/1 returns the system with given id" do
      system = system_fixture()
      assert DataStructures.get_system!(system.id) == system
    end

    test "create_system/1 with valid data creates a system" do
      assert {:ok, %System{} = system} = DataStructures.create_system(@valid_attrs)
      assert system.external_id == "some external_id"
      assert system.name == "some name"
    end

    test "create_system/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_system(@invalid_attrs)
    end

    test "update_system/2 with valid data updates the system" do
      system = system_fixture()
      assert {:ok, %System{} = system} = DataStructures.update_system(system, @update_attrs)
      assert system.external_id == "some updated external_id"
      assert system.name == "some updated name"
    end

    test "update_system/2 with invalid data returns error changeset" do
      system = system_fixture()
      assert {:error, %Ecto.Changeset{}} = DataStructures.update_system(system, @invalid_attrs)
      assert system == DataStructures.get_system!(system.id)
    end

    test "delete_system/1 deletes the system" do
      system = system_fixture()
      assert {:ok, %System{}} = DataStructures.delete_system(system)
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_system!(system.id) end
    end

    test "get_system_by_external_id/1 gets the system" do
      system = system_fixture()
      assert DataStructures.get_system_by_external_id(system.external_id) == system
    end

    test "get_system_by_name/1 gets the system" do
      system = system_fixture()
      assert DataStructures.get_system_by_name(system.name) == system
    end

    test "change_system/1 returns a system changeset" do
      system = system_fixture()
      assert %Ecto.Changeset{} = DataStructures.change_system(system)
    end
  end
end
