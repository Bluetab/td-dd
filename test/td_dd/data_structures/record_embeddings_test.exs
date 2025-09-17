defmodule TdDd.DataStructures.RecordEmbeddingsTest do
  use TdDd.DataCase

  import Mox

  alias TdCluster.TestHelpers.TdAiMock.Embeddings
  alias TdCluster.TestHelpers.TdAiMock.Indices
  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch
  alias TdDd.DataStructures.RecordEmbeddings

  @moduletag sandbox: :shared

  describe "upsert_from_structures_async/1" do
    test "inserts batches of structure ids with embeddings to upsert" do
      stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
        {:ok, true}
      end)

      data_structure_ids = Enum.map(0..1_279, fn i -> i end)
      assert {:ok, jobs} = RecordEmbeddings.upsert_from_structures_async(data_structure_ids)

      assert Enum.count(jobs) == 10

      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch) |> Enum.sort_by(& &1.id)

      for chunk_id <- 0..9 do
        assert %Oban.Job{
                 args: %{"data_structure_ids" => ids},
                 inserted_at: inserted_at,
                 scheduled_at: scheduled_at
               } =
                 Enum.at(jobs, chunk_id)

        assert DateTime.compare(inserted_at, scheduled_at) == :eq
        init = chunk_id * 128
        ending = (chunk_id + 1) * 128
        expected = init..(ending - 1) |> Enum.to_list()
        assert Enum.sort(ids) == Enum.sort(expected)
      end
    end

    test "schedules the job for future execution if a time is specified" do
      stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
        {:ok, true}
      end)

      data_structure_ids = [1]

      assert {:ok, [%Oban.Job{}]} =
               RecordEmbeddings.upsert_from_structures_async(data_structure_ids,
                 schedule_in: 60 * 60
               )

      assert [%Oban.Job{inserted_at: inserted_at, scheduled_at: scheduled_at}] =
               all_enqueued(worker: EmbeddingsUpsertBatch)

      inserted_at = DateTime.truncate(inserted_at, :second)
      scheduled_at = DateTime.truncate(scheduled_at, :second)

      assert DateTime.compare(DateTime.add(inserted_at, 1, :hour), scheduled_at) == :eq
    end

    test "returns noop when there are not indices enabled" do
      stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
        {:ok, false}
      end)

      assert :noop == RecordEmbeddings.upsert_from_structures_async([1])
      assert [] == all_enqueued(worker: EmbeddingsUpsertBatch)
    end
  end

  describe "upsert_from_structures/1" do
    setup do
      IndexWorkerMock.clear()
      on_exit(fn -> IndexWorkerMock.clear() end)
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    test "inserts a list for record embeddings" do
      versions = insert_list(5, :data_structure_version)
      data_structure_ids = Enum.map(versions, & &1.data_structure_id)
      vectors = Enum.map(1..5, fn _ -> [54.0, 10.2, -2.0] end)
      alias_name = ""
      domain_external_id = ""

      Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      Embeddings.list(
        &Mox.expect/4,
        Enum.map(versions, fn %{name: name, type: type, description: description} ->
          "#{name} #{alias_name} #{type} #{domain_external_id} #{description}"
        end),
        {:ok, %{"default" => vectors, "other" => vectors}}
      )

      assert {10, nil} == RecordEmbeddings.upsert_from_structures(data_structure_ids)
      assert record_embeddings = Repo.all(RecordEmbedding)
      assert Enum.count(record_embeddings) == 10

      for %{id: id} <- versions do
        version_embeddings = Enum.filter(record_embeddings, &(&1.data_structure_version_id == id))
        assert Enum.count(version_embeddings) == 2
        default_embedding = Enum.find(version_embeddings, &(&1.collection == "default"))
        assert default_embedding.embedding == [54.0, 10.2, -2.0]
        assert default_embedding.dims == 3

        other_embedding = Enum.find(version_embeddings, &(&1.collection == "other"))
        assert other_embedding.embedding == [54.0, 10.2, -2.0]
        assert other_embedding.dims == 3
      end

      assert [{:put_embeddings, :structures, embeddings_for_structure_ids}] =
               IndexWorkerMock.calls()

      assert embeddings_for_structure_ids == data_structure_ids
    end

    test "upserts a record embedding on conflict" do
      record_embedding =
        insert(:record_embedding, embedding: [-1, 1], dims: 2, collection: "default")

      data_structure_version = record_embedding.data_structure_version
      alias_name = ""
      domain_external_id = ""

      Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      Embeddings.list(
        &Mox.expect/4,
        [
          "#{data_structure_version.name} #{alias_name} #{data_structure_version.type} #{domain_external_id} #{data_structure_version.description}"
        ],
        {:ok, %{"default" => [[-2.0, 2.0, 3.0]]}}
      )

      assert {1, nil} ==
               RecordEmbeddings.upsert_from_structures([data_structure_version.data_structure_id])

      assert [record_embedding] = Repo.all(RecordEmbedding)
      assert record_embedding.collection == "default"
      assert record_embedding.embedding == [-2.0, 2.0, 3.0]
      assert record_embedding.dims == 3

      assert [{:put_embeddings, :structures, embeddings_for_structure_ids}] =
               IndexWorkerMock.calls()

      assert embeddings_for_structure_ids == [data_structure_version.data_structure_id]
    end

    test "returns 0 upserted records if structures are not found" do
      Indices.exists_enabled?(&Mox.expect/4, {:ok, true})
      assert {0, nil} = RecordEmbeddings.upsert_from_structures([1])
    end

    test "returns noop when there aren't any indices enabled" do
      Indices.exists_enabled?(&Mox.expect/4, {:ok, false})

      assert :noop == RecordEmbeddings.upsert_from_structures([1])
    end
  end

  describe "upsert_outdated_async/1" do
    test "upserts data structure ids with stale record embeddings" do
      Indices.list_indices(
        &Mox.expect/4,
        [enabled: true],
        {:ok, [%{collection_name: "default"}, %{collection_name: "other"}]}
      )

      Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      dsv_without_embedding = insert(:data_structure_version)
      deleted_dsv = insert(:data_structure_version, deleted_at: DateTime.utc_now())
      insert(:record_embedding, data_structure_version: deleted_dsv, collection: "default")
      insert(:record_embedding, data_structure_version: deleted_dsv, collection: "other")
      %{data_structure_version: updated_dsv} = insert(:record_embedding, collection: "default")
      insert(:record_embedding, collection: "other", data_structure_version: updated_dsv)

      %{data_structure_version: outdated_dsv} =
        insert(:record_embedding,
          updated_at: DateTime.add(DateTime.utc_now(), -1, :day),
          collection: "default"
        )

      insert(:record_embedding,
        updated_at: DateTime.add(DateTime.utc_now(), -1, :day),
        collection: "other",
        data_structure_version: outdated_dsv
      )

      assert {:ok, jobs} = RecordEmbeddings.upsert_outdated_async()

      assert Enum.count(jobs) == 1

      assert [%Oban.Job{args: %{"data_structure_ids" => data_structure_ids}}] =
               all_enqueued(worker: EmbeddingsUpsertBatch)

      assert MapSet.equal?(
               MapSet.new(data_structure_ids),
               MapSet.new([
                 outdated_dsv.data_structure_id,
                 dsv_without_embedding.data_structure_id
               ])
             )
    end

    test "returns noop when there are no indices enabled" do
      Indices.list_indices(&Mox.expect/4, [enabled: true], {:ok, []})
      assert :noop == RecordEmbeddings.upsert_outdated_async()
    end
  end

  describe "delete_stale_record_embeddings/1" do
    test "deletes record embeddings that are not in enabled indices and deleted data structure versions" do
      data_structure_version = insert(:data_structure_version, deleted_at: DateTime.utc_now())

      record_embedding_to_delete =
        insert(:record_embedding, data_structure_version: data_structure_version)

      other_record_embedding = insert(:record_embedding, collection: "other")
      record_embedding_to_keep = insert(:record_embedding)

      Indices.list_indices(
        &Mox.expect/4,
        [enabled: true],
        {:ok, [%{collection_name: "default"}]}
      )

      assert {:ok,
              %{
                from_disabled_indices: {1, [disabled_index]},
                from_deleted_data_structure_versions: {1, [deleted_version]}
              }} =
               RecordEmbeddings.delete_stale_record_embeddings()

      assert disabled_index.id == other_record_embedding.id
      assert deleted_version.id == record_embedding_to_delete.id

      assert [record_embedding] = Repo.all(RecordEmbedding)
      assert record_embedding.id == record_embedding_to_keep.id

      assert Repo.get!(DataStructureVersion, data_structure_version.id)
      assert Repo.get!(DataStructureVersion, other_record_embedding.data_structure_version_id)
    end

    test "deletes all records if there are not enabled indices" do
      Indices.list_indices(&Mox.expect/4, [enabled: true], {:ok, []})

      record_embedding = insert(:record_embedding)
      assert {1, nil} = RecordEmbeddings.delete_stale_record_embeddings()
      assert [] == Repo.all(RecordEmbedding)
      assert [data_structure_version] = Repo.all(TdDd.DataStructures.DataStructureVersion)
      assert data_structure_version.id == record_embedding.data_structure_version_id
    end
  end
end
