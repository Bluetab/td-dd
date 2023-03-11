defmodule TdDd.DataStructures.DataStructureLinkTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.Repo

  describe "changeset/1" do
    test "valid params" do
      %{id: source_structure_id} = insert(:data_structure, external_id: "source_external_id")
      %{id: target_structure_id} = insert(:data_structure, external_id: "target_external_id")

      assert %Ecto.Changeset{valid?: true} =
               DataStructureLink.changeset(%{
                 source_id: source_structure_id,
                 target_id: target_structure_id,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
    end

    test "invalid params" do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               DataStructureLink.changeset(%{
                 source_id: "source_id_cannot_be_string",
                 target_id: "source_id_cannot_be_string",
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })

      assert {_message, [type: :id, validation: :cast]} = errors[:source_id]
      assert {_message, [type: :id, validation: :cast]} = errors[:target_id]
    end

    test "detects missing required fields" do
      assert %{errors: errors} = DataStructureLink.changeset(%{})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:source_external_id]
      assert {_message, [validation: :required]} = errors[:target_external_id]
    end

    test "detects foreign key constraint violation, source_id" do
      assert {:error, %{errors: errors}} =
               DataStructureLink.changeset(%{
                 source_id: 1234,
                 target_id: 1235,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
               |> Repo.insert()

      assert {_message, info} = errors[:source_id]
      assert info[:constraint] == :foreign
    end

    test "detects foreign key constraint violation, target_id" do
      %{id: source_structure_id} = insert(:data_structure, external_id: "source_external_id")

      assert {:error, %{errors: errors}} =
               DataStructureLink.changeset(%{
                 source_id: source_structure_id,
                 target_id: 1235,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
               |> Repo.insert()

      assert {_message, info} = errors[:target_id]
      assert info[:constraint] == :foreign
    end
  end

  describe "changeset_from_ids/1" do
    test "valid params" do
      %{id: source_structure_id} = insert(:data_structure, external_id: "source_external_id")
      %{id: target_structure_id} = insert(:data_structure, external_id: "target_external_id")

      assert %Ecto.Changeset{valid?: true} =
               DataStructureLink.changeset_from_ids(%{
                 source_id: source_structure_id,
                 target_id: target_structure_id,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
    end

    test "invalid params" do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               DataStructureLink.changeset_from_ids(%{
                 source_id: "source_id_cannot_be_string",
                 target_id: "source_id_cannot_be_string",
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })

      assert {_message, [type: :id, validation: :cast]} = errors[:source_id]
      assert {_message, [type: :id, validation: :cast]} = errors[:target_id]
    end

    test "detects missing required fields" do
      assert %{errors: errors} = DataStructureLink.changeset_from_ids(%{})
      assert length(errors) == 2
      assert {_message, [validation: :required]} = errors[:source_id]
      assert {_message, [validation: :required]} = errors[:target_id]
    end

    test "detects foreign key constraint violation, source_id" do
      assert {:error, %{errors: errors}} =
               DataStructureLink.changeset_from_ids(%{
                 source_id: 1234,
                 target_id: 1235,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
               |> Repo.insert()

      assert {_message, info} = errors[:source_id]
      assert info[:constraint] == :foreign
    end

    test "detects foreign key constraint violation, target_id" do
      %{id: data_structure_id} = insert(:data_structure, external_id: "source_external_id")

      assert {:error, %{errors: errors}} =
               DataStructureLink.changeset_from_ids(%{
                 source_id: data_structure_id,
                 target_id: 1235,
                 source_external_id: "source_external_id",
                 target_external_id: "target_external_id"
               })
               |> Repo.insert()

      assert {_message, info} = errors[:target_id]
      assert info[:constraint] == :foreign
    end
  end
end
