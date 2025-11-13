defmodule TdDd.Loader.VersionsTest do
  use TdDd.DataCase

  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Loader.Versions
  alias TdDd.Repo

  setup do
    [system: insert(:system)]
  end

  describe "delete_missing_versions/4" do
    setup %{system: %{id: system_id}} do
      data_structure_versions =
        Enum.map(1..20, fn i ->
          insert(:data_structure_version,
            data_structure: build(:data_structure, system_id: system_id),
            group: if(Integer.mod(i, 2) == 0, do: "group1", else: "group2")
          )
        end)

      structure_id_map =
        Map.new(data_structure_versions, fn
          %{data_structure: %{id: id, external_id: external_id}} -> {external_id, id}
        end)

      context = %{structure_id_map: structure_id_map}

      [data_structure_versions: data_structure_versions, context: context]
    end

    test "logically deletes versions which are not present in the records", %{
      context: context,
      data_structure_versions: data_structure_versions
    } do
      %{data_structure: %{external_id: external_id, system_id: system_id}} =
        Enum.find(data_structure_versions, &(&1.group == "group1"))

      structure_records = [
        %{group: "group1", external_id: "foo", system_id: system_id},
        %{group: "group1", external_id: external_id, system_id: system_id}
      ]

      ts = DateTime.utc_now()

      assert {:ok, {9, data_structure_ids}} =
               Versions.delete_missing_versions(Repo, %{context: context}, structure_records, ts)

      assert [{^ts, 9}] =
               DataStructureVersion
               |> where([dsv], dsv.data_structure_id in ^data_structure_ids)
               |> group_by(:deleted_at)
               |> select([dsv], {dsv.deleted_at, count(dsv.id)})
               |> Repo.all()

      assert [{"group1", 9}] =
               DataStructureVersion
               |> where([dsv], not is_nil(dsv.deleted_at))
               |> group_by(:group)
               |> select([dsv], {dsv.group, count(dsv.id)})
               |> Repo.all()

      assert [{"group1", 1}, {"group2", 10}] =
               DataStructureVersion
               |> where([dsv], is_nil(dsv.deleted_at))
               |> group_by(:group)
               |> select([dsv], {dsv.group, count(dsv.id)})
               |> Repo.all()
    end
  end

  describe "insert_new_versions/3" do
    test "inserts new data structures", %{system: %{id: system_id}} do
      entries = [
        %{external_id: "foo", system_id: system_id},
        %{external_id: "bar", system_id: system_id},
        %{external_id: "baz", system_id: system_id}
      ]

      ts = DateTime.utc_now()
      context = %{entries: entries, structure_id_map: %{"bar" => 22}}

      assert {:ok, {2, versions}} = Versions.insert_new_versions(Repo, %{context: context}, ts)

      assert [
               %{external_id: "baz", system_id: ^system_id},
               %{external_id: "foo", system_id: ^system_id}
             ] =
               DataStructure
               |> where([ds], ds.id in ^Enum.map(versions, & &1.data_structure_id))
               |> order_by(:external_id)
               |> Repo.all()
    end
  end

  describe "restore_deleted_versions/2" do
    test "restores logically deleted versions whose ghash is unchanged" do
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]

      %{id: foo_id, data_structure_id: structure_id} =
        insert(:data_structure_version, ghash: "foog", deleted_at: deleted_at)

      %{id: bar_id} = insert(:data_structure_version, ghash: "barg")

      context = %{
        ghash: %{
          "foog" => %{id: foo_id, deleted_at: deleted_at},
          "barg" => %{id: bar_id, deleted_at: nil}
        }
      }

      assert {:ok, {1, [^structure_id]}} =
               Versions.restore_deleted_versions(Repo, %{context: context})

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
    end

    test "restores StructureMetadata when restoring deleted versions" do
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]

      %{id: foo_id, data_structure_id: structure_id} =
        insert(:data_structure_version, ghash: "foog", deleted_at: deleted_at)

      %{id: metadata_id} =
        insert(:structure_metadata,
          data_structure_id: structure_id,
          version: 0,
          deleted_at: deleted_at
        )

      context = %{
        ghash: %{
          "foog" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, [^structure_id]}} =
               Versions.restore_deleted_versions(Repo, %{context: context})

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_id)
    end

    test "restores StructureMetadata for multiple structures" do
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]

      %{id: foo_id, data_structure_id: structure_id1} =
        insert(:data_structure_version, ghash: "foog", deleted_at: deleted_at)

      %{id: bar_id, data_structure_id: structure_id2} =
        insert(:data_structure_version, ghash: "barg", deleted_at: deleted_at)

      %{id: metadata_id1} =
        insert(:structure_metadata,
          data_structure_id: structure_id1,
          version: 0,
          deleted_at: deleted_at
        )

      %{id: metadata_id2} =
        insert(:structure_metadata,
          data_structure_id: structure_id2,
          version: 0,
          deleted_at: deleted_at
        )

      context = %{
        ghash: %{
          "foog" => %{id: foo_id, deleted_at: deleted_at},
          "barg" => %{id: bar_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {2, structure_ids}} =
               Versions.restore_deleted_versions(Repo, %{context: context})

      assert length(structure_ids) == 2
      assert structure_id1 in structure_ids
      assert structure_id2 in structure_ids

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, bar_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_id1)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_id2)
    end

    test "does not restore StructureMetadata that is not deleted" do
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]

      %{id: foo_id, data_structure_id: structure_id} =
        insert(:data_structure_version, ghash: "foog", deleted_at: deleted_at)

      %{id: active_metadata_id} =
        insert(:structure_metadata,
          data_structure_id: structure_id,
          version: 0,
          deleted_at: nil
        )

      context = %{
        ghash: %{
          "foog" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, [^structure_id]}} =
               Versions.restore_deleted_versions(Repo, %{context: context})

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, active_metadata_id)
    end

    test "restores only latest StructureMetadata version when multiple deleted versions exist" do
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]

      %{id: foo_id, data_structure_id: structure_id} =
        insert(:data_structure_version, ghash: "foog", deleted_at: deleted_at)

      %{id: metadata_v0_id} =
        insert(:structure_metadata,
          data_structure_id: structure_id,
          version: 0,
          deleted_at: deleted_at
        )

      %{id: metadata_v1_id} =
        insert(:structure_metadata,
          data_structure_id: structure_id,
          version: 1,
          deleted_at: deleted_at
        )

      %{id: metadata_v2_id} =
        insert(:structure_metadata,
          data_structure_id: structure_id,
          version: 2,
          deleted_at: deleted_at
        )

      context = %{
        ghash: %{
          "foog" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, [^structure_id]}} =
               Versions.restore_deleted_versions(Repo, %{context: context})

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: ^deleted_at} = Repo.get!(StructureMetadata, metadata_v0_id)
      assert %{deleted_at: ^deleted_at} = Repo.get!(StructureMetadata, metadata_v1_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_v2_id)
    end
  end

  describe "update_existing_versions/3" do
    test "updates existing versions whose lhash is unchanged" do
      inserted_at = ~U[2000-01-01T01:23:45.123456Z]
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id} =
        insert(:data_structure_version,
          lhash: "fool",
          inserted_at: inserted_at,
          deleted_at: deleted_at
        )

      %{id: bar_id} = insert(:data_structure_version, lhash: "barl", inserted_at: inserted_at)

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", external_id: "foo"},
          %{ghash: "barg", lhash: "barl", external_id: "bar"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id},
          "bar" => %{id: bar_id}
        },
        ghash: %{},
        lhash: %{
          "fool" => %{id: foo_id, deleted_at: deleted_at},
          "barl" => %{id: bar_id, deleted_at: nil}
        }
      }

      assert {:ok, {2, versions}} =
               Versions.update_existing_versions(Repo, %{context: context}, ts)

      assert [
               %{
                 id: ^bar_id,
                 ghash: "barg",
                 lhash: "barl",
                 inserted_at: ^inserted_at,
                 updated_at: ^ts,
                 deleted_at: nil
               },
               %{
                 id: ^foo_id,
                 ghash: "foog",
                 lhash: "fool",
                 inserted_at: ^inserted_at,
                 updated_at: ^ts,
                 deleted_at: nil
               }
             ] =
               DataStructureVersion
               |> where([dsv], dsv.id in ^Enum.map(versions, & &1.id))
               |> order_by(:lhash)
               |> Repo.all()
    end

    test "restores StructureMetadata when reactivating deleted versions" do
      inserted_at = ~U[2000-01-01T01:23:45.123456Z]
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id, data_structure_id: foo_structure_id} =
        insert(:data_structure_version,
          lhash: "fool",
          inserted_at: inserted_at,
          deleted_at: deleted_at
        )

      %{id: metadata_id} =
        insert(:structure_metadata,
          data_structure_id: foo_structure_id,
          version: 0,
          deleted_at: deleted_at
        )

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", external_id: "foo"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id}
        },
        ghash: %{},
        lhash: %{
          "fool" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, _versions}} =
               Versions.update_existing_versions(Repo, %{context: context}, ts)

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_id)
    end

    test "works correctly with single DataStructure and single StructureMetadata" do
      inserted_at = ~U[2000-01-01T01:23:45.123456Z]
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id, data_structure_id: foo_structure_id} =
        insert(:data_structure_version,
          lhash: "fool",
          inserted_at: inserted_at,
          deleted_at: deleted_at
        )

      %{id: metadata_id} =
        insert(:structure_metadata,
          data_structure_id: foo_structure_id,
          version: 0,
          deleted_at: deleted_at
        )

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", external_id: "foo"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id}
        },
        ghash: %{},
        lhash: %{
          "fool" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, _versions}} =
               Versions.update_existing_versions(Repo, %{context: context}, ts)

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_id)
    end

    test "works correctly when StructureMetadata does not exist" do
      inserted_at = ~U[2000-01-01T01:23:45.123456Z]
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id, data_structure_id: foo_structure_id} =
        insert(:data_structure_version,
          lhash: "fool",
          inserted_at: inserted_at,
          deleted_at: deleted_at
        )

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", external_id: "foo"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id}
        },
        ghash: %{},
        lhash: %{
          "fool" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, _versions}} =
               Versions.update_existing_versions(Repo, %{context: context}, ts)

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)

      metadata_count =
        StructureMetadata
        |> where([sm], sm.data_structure_id == ^foo_structure_id)
        |> Repo.aggregate(:count, :id)

      assert metadata_count == 0
    end

    test "restores only latest StructureMetadata version when multiple deleted versions exist" do
      inserted_at = ~U[2000-01-01T01:23:45.123456Z]
      deleted_at = ~U[2001-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id, data_structure_id: foo_structure_id} =
        insert(:data_structure_version,
          lhash: "fool",
          inserted_at: inserted_at,
          deleted_at: deleted_at
        )

      %{id: metadata_v0_id} =
        insert(:structure_metadata,
          data_structure_id: foo_structure_id,
          version: 0,
          deleted_at: deleted_at
        )

      %{id: metadata_v1_id} =
        insert(:structure_metadata,
          data_structure_id: foo_structure_id,
          version: 1,
          deleted_at: deleted_at
        )

      %{id: metadata_v2_id} =
        insert(:structure_metadata,
          data_structure_id: foo_structure_id,
          version: 2,
          deleted_at: deleted_at
        )

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", external_id: "foo"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id}
        },
        ghash: %{},
        lhash: %{
          "fool" => %{id: foo_id, deleted_at: deleted_at}
        }
      }

      assert {:ok, {1, _versions}} =
               Versions.update_existing_versions(Repo, %{context: context}, ts)

      assert %{deleted_at: nil} = Repo.get!(DataStructureVersion, foo_id)
      assert %{deleted_at: ^deleted_at} = Repo.get!(StructureMetadata, metadata_v0_id)
      assert %{deleted_at: ^deleted_at} = Repo.get!(StructureMetadata, metadata_v1_id)
      assert %{deleted_at: nil} = Repo.get!(StructureMetadata, metadata_v2_id)
    end
  end

  describe "replace_changed_versions/3" do
    test "replaces existing versions whose hash has unchanged" do
      ts1 = ~U[2000-01-01T01:23:45.123456Z]
      ts = DateTime.utc_now()

      %{id: foo_id, data_structure_id: foo_structure_id} =
        insert(:data_structure_version, inserted_at: ts1, updated_at: ts1)

      %{id: bar_id, data_structure_id: bar_structure_id} =
        insert(:data_structure_version, inserted_at: ts1, updated_at: ts1, version: 1)

      context = %{
        entries: [
          %{ghash: "foog", lhash: "fool", hash: "fooh", external_id: "foo"},
          %{ghash: "barg", lhash: "barl", hash: "barh", external_id: "bar"}
        ],
        version_id_map: %{
          "foo" => %{id: foo_id, version: 0},
          "bar" => %{id: bar_id, version: 1}
        },
        structure_id_map: %{
          "foo" => foo_structure_id,
          "bar" => bar_structure_id
        },
        ghash: %{},
        lhash: %{}
      }

      assert {:ok, {4, versions}} =
               Versions.replace_changed_versions(Repo, %{context: context}, ts)

      assert [
               %{id: ^foo_id, inserted_at: ^ts1, updated_at: ^ts1, deleted_at: ^ts, version: 0},
               %{
                 data_structure_id: ^foo_structure_id,
                 inserted_at: ^ts,
                 updated_at: ^ts,
                 deleted_at: nil,
                 hash: "fooh",
                 lhash: "fool",
                 ghash: "foog",
                 version: 1
               },
               %{id: ^bar_id, inserted_at: ^ts1, updated_at: ^ts1, deleted_at: ^ts, version: 1},
               %{
                 data_structure_id: ^bar_structure_id,
                 inserted_at: ^ts,
                 updated_at: ^ts,
                 deleted_at: nil,
                 hash: "barh",
                 lhash: "barl",
                 ghash: "barg",
                 version: 2
               }
             ] =
               DataStructureVersion
               |> where([dsv], dsv.id in ^Enum.map(versions, & &1.id))
               |> order_by([:data_structure_id, :version])
               |> Repo.all()
    end
  end
end
