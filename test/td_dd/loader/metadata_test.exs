defmodule TdDd.Loader.MetadataTest do
  use TdDd.DataCase

  import Ecto.Query

  alias TdDd.CSV.Reader
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Loader
  alias TdDd.Loader.Metadata
  alias TdDd.Repo

  @structure_import_schema Application.compile_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.compile_env(:td_dd, :metadata)[
                               :structure_import_required
                             ]
  @relation_import_schema Application.compile_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.compile_env(:td_dd, :metadata)[:relation_import_required]

  describe "Loader.load/2" do
    test "inserts and logically deletes mutable metadata" do
      %{id: system_id} = insert(:system)

      assert {:ok, structures_1} =
               parse_structures("test/fixtures/loader/mutable_metadata/structures.csv", system_id)

      assert {:ok, structures_2} =
               parse_structures(
                 "test/fixtures/loader/mutable_metadata/structures2.csv",
                 system_id
               )

      assert {:ok, rels} =
               parse_relations("test/fixtures/loader/mutable_metadata/relations.csv", system_id)

      audit1 = %{ts: ~U[2020-01-01T00:00:00.123456Z], last_change_by: 0}
      audit2 = %{ts: ~U[2020-02-02T00:00:00.123456Z], last_change_by: 0}
      assert {:ok, multi} = Loader.load(%{structures: structures_1, relations: rels}, audit1, [])
      assert %{insert_versions: {890, _inserted_versions}} = multi
      assert {:ok, multi} = Loader.load(%{structures: structures_2, relations: rels}, audit2, [])
      assert %{replace_metadata: updated_ids} = multi
      assert length(updated_ids) == 3

      metadata_by_external_id =
        StructureMetadata
        |> where([m], m.data_structure_id in ^updated_ids)
        |> preload(:data_structure)
        |> Repo.all()
        |> Enum.group_by(
          & &1.data_structure.external_id,
          &Map.take(&1, [:inserted_at, :updated_at, :deleted_at, :version])
        )
        |> Map.new(fn {k, v} -> {k, Enum.sort_by(v, & &1.version)} end)

      assert metadata_by_external_id["foo://foo_db/bank_capital/should_insert_metadata"] == [
               %{
                 deleted_at: nil,
                 inserted_at: ~U[2020-02-02 00:00:00.123456Z],
                 updated_at: ~U[2020-02-02 00:00:00.123456Z],
                 version: 0
               }
             ]

      assert metadata_by_external_id["foo://foo_db/should_delete_metadata"] == [
               %{
                 deleted_at: ~U[2020-02-02 00:00:00.123456Z],
                 inserted_at: ~U[2020-01-01 00:00:00.123456Z],
                 updated_at: ~U[2020-01-01 00:00:00.123456Z],
                 version: 0
               }
             ]

      assert metadata_by_external_id["foo://foo_db/should_replace_metadata"] == [
               %{
                 deleted_at: ~U[2020-02-02 00:00:00.123456Z],
                 inserted_at: ~U[2020-01-01 00:00:00.123456Z],
                 updated_at: ~U[2020-01-01 00:00:00.123456Z],
                 version: 0
               },
               %{
                 deleted_at: nil,
                 inserted_at: ~U[2020-02-02 00:00:00.123456Z],
                 updated_at: ~U[2020-02-02 00:00:00.123456Z],
                 version: 1
               }
             ]
    end
  end

  describe "missing_external_ids/4" do
    test "identifies external_ids which don't exist in the system" do
      %{external_id: external_id1, system: system} = insert(:data_structure)
      %{external_id: external_id2} = insert(:data_structure)

      records = [
        %{external_id: "foo"},
        %{external_id: external_id1},
        %{external_id: external_id2}
      ]

      assert {:error, ["foo", ^external_id2]} =
               Metadata.missing_external_ids(Repo, %{}, records, system)
    end

    test "returns ok and empty list if all external_ids exist" do
      %{external_id: external_id1, system: system} = insert(:data_structure)

      records = [%{external_id: external_id1}]
      assert {:ok, []} = Metadata.missing_external_ids(Repo, %{}, records, system)
    end
  end

  describe "merge_existing_fields/1" do
    test "merges fields into existing metadata" do
      %{fields: fields, data_structure: %{external_id: external_id1}} =
        insert(:structure_metadata)

      %{data_structure: %{external_id: external_id2}} = insert(:structure_metadata)
      %{data_structure: %{external_id: external_id3}} = insert(:structure_metadata)
      %{data_structure: %{external_id: external_id4}} = insert(:structure_metadata)

      records = [
        %{external_id: external_id1, mutable_metadata: fields},
        %{external_id: external_id2, mutable_metadata: %{"xyzzy" => "xyzzy", "foo" => [1, 2, 3]}},
        %{external_id: external_id3, mutable_metadata: %{"xyzzy" => "xyzzy"}},
        %{external_id: external_id4, mutable_metadata: %{"foo" => "foo"}}
      ]

      assert Metadata.merge_existing_fields(records) == %{
               external_id2 => %{"foo" => [1, 2, 3], "xyzzy" => "xyzzy"},
               external_id3 => %{"foo" => "bar", "xyzzy" => "xyzzy"},
               external_id4 => %{"foo" => "foo"}
             }
    end
  end

  describe "merge_metadata/2" do
    test "returns ok and empty list if no records are merged" do
      assert Metadata.merge_metadata([], DateTime.utc_now()) == {:ok, []}
    end

    test "returns ok and list of updated structure ids if records are merged" do
      %{fields: fields, data_structure: %{external_id: external_id1}} =
        insert(:structure_metadata)

      %{data_structure: %{id: id2, external_id: external_id2}} = insert(:structure_metadata)
      %{data_structure: %{id: id3, external_id: external_id3}} = insert(:structure_metadata)
      %{data_structure: %{id: id4, external_id: external_id4}} = insert(:structure_metadata)

      records = [
        %{external_id: external_id1, mutable_metadata: fields},
        %{external_id: external_id2, mutable_metadata: %{"xyzzy" => "xyzzy", "foo" => [1, 2, 3]}},
        %{external_id: external_id3, mutable_metadata: %{"xyzzy" => "xyzzy"}},
        %{external_id: external_id4, mutable_metadata: %{"foo" => "foo"}}
      ]

      assert {:ok, updated_ids} = Metadata.merge_metadata(records, DateTime.utc_now())
      assert_lists_equal(updated_ids, [id2, id3, id4])
    end
  end

  defp parse_structures(path, system_id) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: %{domain_id: 1, system_id: system_id},
      schema: @structure_import_schema,
      required: @structure_import_required,
      booleans: []
    )
  end

  defp parse_relations(path, system_id) do
    path
    |> File.stream!()
    |> Reader.read_csv(
      defaults: %{domain_id: 1, system_id: system_id},
      schema: @relation_import_schema,
      required: @relation_import_required
    )
  end
end
