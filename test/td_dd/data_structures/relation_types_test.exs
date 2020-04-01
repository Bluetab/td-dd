defmodule TdDd.DataStructures.RelationTypesTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes

  describe "relation_types" do
    @valid_attrs %{description: "some description", name: "some name"}
    @update_attrs %{description: "some updated description", name: "some updated name"}
    @invalid_attrs %{description: nil, name: nil}

    def relation_type_fixture(attrs \\ %{}) do
      {:ok, relation_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> RelationTypes.create_relation_type()

      relation_type
    end

    test "list_relation_types/0 returns all relation_types" do
      relation_type = relation_type_fixture()
      default_relation_type = RelationTypes.get_default()
      assert RelationTypes.list_relation_types() == [default_relation_type, relation_type]
    end

    test "get_relation_type!/1 returns the relation_type with given id" do
      relation_type = relation_type_fixture()
      assert RelationTypes.get_relation_type!(relation_type.id) == relation_type
    end

    test "create_relation_type/1 with valid data creates a relation_type" do
      assert {:ok, %RelationType{} = relation_type} =
               RelationTypes.create_relation_type(@valid_attrs)

      assert relation_type.description == "some description"
      assert relation_type.name == "some name"
    end

    test "create_relation_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = RelationTypes.create_relation_type(@invalid_attrs)
    end

    test "update_relation_type/2 with valid data updates the relation_type" do
      relation_type = relation_type_fixture()

      assert {:ok, %RelationType{} = relation_type} =
               RelationTypes.update_relation_type(relation_type, @update_attrs)

      assert relation_type.description == "some updated description"
      assert relation_type.name == "some updated name"
    end

    test "update_relation_type/2 with invalid data returns error changeset" do
      relation_type = relation_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               RelationTypes.update_relation_type(relation_type, @invalid_attrs)

      assert relation_type == RelationTypes.get_relation_type!(relation_type.id)
    end

    test "delete_relation_type/1 deletes the relation_type" do
      relation_type = relation_type_fixture()
      assert {:ok, %RelationType{}} = RelationTypes.delete_relation_type(relation_type)

      assert_raise Ecto.NoResultsError, fn ->
        RelationTypes.get_relation_type!(relation_type.id)
      end
    end

    test "with_relation_types/1 returns records with relation types" do
      external_id = "parent_external_id"
      child_external_id = "child_external_id"

      system = insert(:system)
      ds = insert(:data_structure, external_id: external_id, system_id: system.id)
      version = insert(:data_structure_version, data_structure_id: ds.id)
      structures = [{ds.external_id, version}]
      relations = [%{parent_external_id: ds.external_id, child_external_id: child_external_id}]

      results =
        Enum.map(relations, &Map.merge(&1, %{relation_type_id: 1, relation_type_name: "default"}))

      assert {structures, results} == RelationTypes.with_relation_types({structures, relations})

      relation_type = insert(:relation_type)
      r1 = %{child_external_id: child_external_id, parent_external_id: external_id}

      r2 = %{
        child_external_id: "desc_2",
        relation_type_name: "",
        parent_external_id: child_external_id
      }

      r3 = %{
        child_external_id: "desc_3",
        relation_type_name: relation_type.name,
        parent_external_id: child_external_id
      }

      results = RelationTypes.with_relation_types([r1, r2, r3])

      assert Enum.find(results, &(&1.child_external_id == r1.child_external_id)) ==
               Map.merge(r1, %{relation_type_id: 1, relation_type_name: "default"})

      assert Enum.find(results, &(&1.child_external_id == r2.child_external_id)) ==
               Map.merge(r2, %{relation_type_id: 1, relation_type_name: "default"})

      assert Enum.find(results, &(&1.child_external_id == r3.child_external_id)) ==
               Map.merge(r3, %{
                 relation_type_id: relation_type.id,
                 relation_type_name: relation_type.name
               })
    end
  end
end
