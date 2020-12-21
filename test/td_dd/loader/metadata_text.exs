defmodule TdDd.Loader.MetadataTest do
  use TdDd.DataCase

  import Ecto.Query

  alias TdDd.CSV.Reader
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Loader
  alias TdDd.Repo

  @structure_import_schema Application.compile_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.compile_env(:td_dd, :metadata)[
                               :structure_import_required
                             ]
  @relation_import_schema Application.compile_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.compile_env(:td_dd, :metadata)[:relation_import_required]

  describe "load/2" do
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

      audit1 = %{ts: ~U[2020-01-01T00:00:00Z], last_change_by: 0}
      audit2 = %{ts: ~U[2020-02-02T00:00:00Z], last_change_by: 0}
      assert {:ok, multi} = Loader.load(structures_1, [], rels, audit1, [])
      assert %{inserted_versions: {890, _inserted_versions}} = multi
      assert {:ok, multi} = Loader.load(structures_2, [], rels, audit2, [])
      assert %{mutable_metadata: updated_ids} = multi
      assert length(updated_ids) == 4

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
                 inserted_at: ~U[2020-02-02 00:00:00Z],
                 updated_at: ~U[2020-02-02 00:00:00Z],
                 version: 0
               }
             ]

      assert metadata_by_external_id["foo://foo_db/should_delete_metadata"] == [
               %{
                 deleted_at: ~U[2020-02-02 00:00:00Z],
                 inserted_at: ~U[2020-01-01 00:00:00Z],
                 updated_at: ~U[2020-01-01 00:00:00Z],
                 version: 0
               }
             ]

      assert metadata_by_external_id["foo://foo_db/should_replace_metadata"] == [
               %{
                 deleted_at: ~U[2020-02-02 00:00:00Z],
                 inserted_at: ~U[2020-01-01 00:00:00Z],
                 updated_at: ~U[2020-01-01 00:00:00Z],
                 version: 0
               },
               %{
                 deleted_at: nil,
                 inserted_at: ~U[2020-02-02 00:00:00Z],
                 updated_at: ~U[2020-02-02 00:00:00Z],
                 version: 1
               }
             ]
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
