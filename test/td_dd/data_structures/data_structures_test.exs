defmodule TdDd.DataStructuresTest do
  use TdDd.DataCase

  alias TdDd.DataStructures

  describe "data_structures" do
    alias TdDd.DataStructures.DataStructure

    @valid_attrs %{description: "some description", group: "some group", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42, name: "some name", system: "some system", metadata: %{}}
    @update_attrs %{description: "some updated description"}
    @invalid_attrs %{description: nil, group: nil, last_change_at: nil, last_change_by: nil, name: nil, system: nil}

    test "list_data_structures/1 returns all data_structures" do
      data_structure = insert(:data_structure)
      assert DataStructures.list_data_structures() == [data_structure]
    end

    test "list_data_structures/1 returns all data_structures form a search" do
      data_structure = insert(:data_structure)
      search_params = %{ou: [data_structure.ou]}
      assert DataStructures.list_data_structures(search_params) == [data_structure]
    end

    test "get_data_structure!/2 returns the data_structure with given id" do
      data_structure = insert(:data_structure)
      assert DataStructures.get_data_structure!(data_structure.id) == data_structure
    end

    test "get_data_structure!/2 returns the data_structure with given id and fields preloaded" do
      data_structure = insert(:data_structure)
      insert(:data_field, name: "first", data_structure_id: data_structure.id)
      data_structure_with_fields = DataStructures.get_data_structure!(data_structure.id, data_fields: true)
      assert data_structure_with_fields.id == data_structure.id
      assert Ecto.assoc_loaded?(data_structure_with_fields.data_fields)
      assert length(data_structure_with_fields.data_fields) == 1
    end

    test "create_data_structure/1 with valid data creates a data_structure" do
      assert {:ok, %DataStructure{} = data_structure} = DataStructures.create_data_structure(@valid_attrs)
      assert data_structure.description == "some description"
      assert data_structure.group == "some group"
      assert data_structure.last_change_at == DateTime.from_naive!(~N[2010-04-17 14:00:00.000000Z], "Etc/UTC")
      assert data_structure.last_change_by == 42
      assert data_structure.name == "some name"
      assert data_structure.system == "some system"
    end

    test "create_data_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_data_structure(@invalid_attrs)
    end

    test "update_data_structure/2 with valid data updates the data_structure" do
      data_structure = insert(:data_structure)
      assert {:ok, data_structure} = DataStructures.update_data_structure(data_structure, @update_attrs)
      assert %DataStructure{} = data_structure
      assert data_structure.description == "some updated description"
    end

    test "delete_data_structure/1 deletes the data_structure" do
      data_structure = insert(:data_structure)
      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(data_structure)
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_structure!(data_structure.id) end
    end

    test "change_data_structure/1 returns a data_structure changeset" do
      data_structure = insert(:data_structure)
      assert %Ecto.Changeset{} = DataStructures.change_data_structure(data_structure)
    end
  end

  describe "data_fields" do
    alias TdDd.DataStructures.DataField

    @valid_attrs %{business_concept_id: "42", description: "some description", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42, name: "some name", nullable: true, precision: "some precision", type: "some type", metadata: %{}}
    @update_attrs %{business_concept_id: "43", description: "some updated description", last_change_at: "2011-05-18 15:01:01.000000Z", last_change_by: 43, name: "some updated name", nullable: false, precision: "some updated precision", type: "some updated type"}
    @invalid_attrs %{business_concept_id: nil, description: nil, last_change_at: nil, last_change_by: nil, name: nil, nullable: nil, precision: nil, type: nil}

    test "list_data_fields/0 returns all data_fields" do
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)
      assert DataStructures.list_data_fields() == [data_field]
    end

    test "get_data_field!/1 returns the data_field with given id" do
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)
      assert DataStructures.get_data_field!(data_field.id) == data_field
    end

    test "create_data_field/1 with valid data creates a data_field" do
      data_structure = insert(:data_structure)
      creation_attrs = Map.put(@valid_attrs, :data_structure_id, data_structure.id)
      assert {:ok, %DataField{} = data_field} = DataStructures.create_data_field(creation_attrs)
      assert data_field.business_concept_id == "42"
      assert data_field.description == "some description"
      assert data_field.last_change_at == DateTime.from_naive!(~N[2010-04-17 14:00:00.000000Z], "Etc/UTC")
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
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)
      assert {:ok, data_field} = DataStructures.update_data_field(data_field, @update_attrs)
      assert %DataField{} = data_field
      assert data_field.description == "some updated description"
    end

    test "delete_data_field/1 deletes the data_field" do
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)
      assert {:ok, %DataField{}} = DataStructures.delete_data_field(data_field)
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_field!(data_field.id) end
    end

    test "change_data_field/1 returns a data_field changeset" do
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)
      assert %Ecto.Changeset{} = DataStructures.change_data_field(data_field)
    end
  end

  describe "data structure fields" do
    test "list_data_structure_fields/2 returns data structure fields" do
      data_structure = insert(:data_structure)
      data_field = insert(:data_field, data_structure_id: data_structure.id)

      data_fields = DataStructures.list_data_structure_fields(data_structure.id)
      assert length(data_fields) == 1
      assert data_fields |> Enum.at(0) |> Map.get(:id) == data_field.id
    end
  end

end
