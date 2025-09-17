defmodule TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsDeletionTest do
  use TdDd.DataCase

  alias TdCluster.TestHelpers.TdAiMock.Indices
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsDeletion

  @moduletag sandbox: :shared

  describe "EmbeddingsDeletion.perform/1" do
    test "deletes stale record deletions" do
      data_structure_version = insert(:data_structure_version, deleted_at: DateTime.utc_now())

      _record_embedding_to_delete =
        insert(:record_embedding, data_structure_version: data_structure_version)

      _other_record_embedding = insert(:record_embedding, collection: "other")
      record_embedding_to_keep = insert(:record_embedding)

      Indices.list_indices(
        &Mox.expect/4,
        [enabled: true],
        {:ok, [%{collection_name: "default"}]}
      )

      assert :ok == perform_job(EmbeddingsDeletion, %{})

      assert [record_embedding] = Repo.all(RecordEmbedding)
      assert record_embedding.id == record_embedding_to_keep.id
    end

    test "deletes all record embeddings when there are no indices enabled" do
      insert(:record_embedding)
      Indices.list_indices(&Mox.expect/4, [enabled: true], {:ok, []})
      assert :ok == perform_job(EmbeddingsDeletion, %{})
      assert [] == Repo.all(RecordEmbedding)
    end
  end
end
