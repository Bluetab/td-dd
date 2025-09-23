defmodule TdDd.DataStructures.DataStructureVersions.Workers.OutdatedEmbeddingsTest do
  use TdDd.DataCase

  alias TdCluster.TestHelpers.TdAiMock.Indices
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch
  alias TdDd.DataStructures.DataStructureVersions.Workers.OutdatedEmbeddings

  describe "OutdatedEmbeddings.perform/1" do
    test "inserts a batch of workers" do
      %{data_structure_version: data_structure_version} =
        insert(:record_embedding, updated_at: DateTime.add(DateTime.utc_now(), -1, :day))

      Indices.list_indices(&Mox.expect/4, [enabled: true], {:ok, [%{collection_name: "default"}]})
      Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      assert :ok == perform_job(OutdatedEmbeddings, %{})

      assert [%Oban.Job{args: %{"data_structure_ids" => data_structure_ids}}] =
               all_enqueued(worker: EmbeddingsUpsertBatch)

      assert data_structure_ids == [data_structure_version.data_structure_id]
    end

    test "cancels job when indices are not enabled" do
      Indices.list_indices(&Mox.expect/4, [enabled: true], {:ok, []})
      assert {:cancel, :indices_disabled} == perform_job(OutdatedEmbeddings, %{})
    end
  end
end
