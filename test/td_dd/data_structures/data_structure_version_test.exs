defmodule TdDd.DataStructures.DataStructureVersionTest do
  use TdDd.DataCase

  alias Elasticsearch.Document
  alias TdDd.DataStructures
  alias TdDd.DataStructures.{DataStructure, DataStructureVersion}
  alias TdDd.Repo

  describe "DataStructureVersion" do
    test "uses type as foreign key" do
      assert %{structure_type: nil, type: type} =
               :data_structure_version
               |> insert()
               |> Repo.preload(:structure_type)

      %{id: id} = insert(:data_structure_type, name: type)

      assert %{structure_type: %{id: ^id}} =
               :data_structure_version
               |> insert(type: type)
               |> Repo.preload(:structure_type)
    end
  end

  describe "Document.encode/1" do
    test "truncates field_type to 32766 bytes" do
      Enum.each([100, 50_000], fn length ->
        field_type = random_string(length)
        assert String.length(field_type) == length

        dsv = insert(:data_structure_version, metadata: %{"type" => field_type})

        assert %{field_type: field_type} = Document.encode(dsv)
        assert String.length(field_type) == min(length, 32_766)
      end)
    end

    test "updated_at takes data structure updated_at date" do
      %{data_structure: %{updated_at: ds_updated_at}} = dsv = insert(:data_structure_version)

      assert %{
               last_change_at: _,
               updated_at: ^ds_updated_at
             } = Document.encode(dsv)
    end

    test "last_change_at takes data structure date as latest" do
      ds = insert(:data_structure, updated_at: ~U[2024-12-31 00:00:00.000000Z])

      %{data_structure: %{updated_at: ds_updated}} =
        dsv =
        insert(:data_structure_version,
          updated_at: ~U[2024-01-01 00:00:00.000000Z],
          data_structure: ds
        )

      assert %{last_change_at: ^ds_updated} = Document.encode(dsv)
    end

    test "last_change_at takes data structure version date as latest" do
      %{id: ds_id} = ds = insert(:data_structure, updated_at: ~U[2024-01-01 00:00:00.000000Z])

      %{updated_at: dsv_updated} =
        dsv =
        insert(:data_structure_version,
          updated_at: ~U[2024-12-31 00:00:00.000000Z],
          data_structure: ds
        )

      assert %{last_change_at: ^dsv_updated} = Document.encode(dsv)

      DataStructures.update_last_change_at(["data_structure:" <> to_string(ds_id)])

      %DataStructureVersion{
        data_structure: %DataStructure{
          id: last_ds_id,
          last_change_at: last_change_at,
          updated_at: updated_at
        }
      } =
        new_dsv =
        DataStructures.get_latest_version_details(ds_id)

      assert %{id: ^last_ds_id, last_change_at: ^updated_at} = Document.encode(new_dsv)
      assert not is_nil(last_change_at)
    end

    test "record_embeddings to be included in documen" do
      %{data_structure_version: version} = insert(:record_embedding)
      version = Repo.preload(version, :record_embeddings)
      assert %{embeddings: embeddings} = Document.encode(version)
      assert embeddings == %{"vector_default" => [1.0, -47.5, 36.0]}
    end
  end

  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
