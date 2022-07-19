defmodule TdDd.DataStructures.TagsTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.Tags
  alias TdDd.Repo

  describe "list_data_structure_tags/0" do
    test "returns all data structure tags" do
      data_structure_tag = insert(:data_structure_tag)
      assert Tags.list_data_structure_tags() == [data_structure_tag]
    end
  end

  describe "list_data_structure_tags/1" do
    test "returns all data structure tags with structure count" do
      %{data_structure_tag: %{id: id, name: name}} = insert(:data_structures_tags)

      assert [%{id: ^id, name: ^name, structure_count: 1}] =
               Tags.list_data_structure_tags(structure_count: true)
    end
  end

  describe "get_data_structure_tag/1" do
    test "returns the data_structure_tag with given id" do
      %{id: id} = data_structure_tag = insert(:data_structure_tag)
      assert Tags.get_data_structure_tag(id: id) == data_structure_tag
    end
  end

  describe "create_data_structure_tag/1" do
    test "with valid data creates a data structure tag" do
      %{name: name} = build(:data_structure_tag)

      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               Tags.create_data_structure_tag(%{name: name})

      assert %{name: ^name} = data_structure_tag
    end

    test "with invalid data returns error changeset" do
      assert {:error, %{valid?: false, errors: errors}} =
               Tags.create_data_structure_tag(%{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "update_data_structure_tag/2" do
    test "with valid data updates the data_structure_tag" do
      data_structure_tag = insert(:data_structure_tag)
      %{name: name} = build(:data_structure_tag)

      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               Tags.update_data_structure_tag(data_structure_tag, %{name: name})

      assert %{name: ^name} = data_structure_tag
    end

    test "with invalid data returns error changeset" do
      data_structure_tag = insert(:data_structure_tag)

      assert {:error, %{valid?: false, errors: errors}} =
               Tags.update_data_structure_tag(data_structure_tag, %{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "delete_data_structure_tag/1" do
    test "deletes the data structure tag" do
      %{id: id} = data_structure_tag = insert(:data_structure_tag)

      assert {:ok, %DataStructureTag{__meta__: %{state: :deleted}}} =
               Tags.delete_data_structure_tag(data_structure_tag)

      refute Repo.get(DataStructureTag, id)
    end
  end
end
