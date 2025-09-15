defmodule TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatchTest do
  use TdDd.DataCase

  alias TdCluster.TestHelpers.TdAiMock.Embeddings
  alias TdCluster.TestHelpers.TdAiMock.Indices
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch

  @moduletag sandbox: :shared

  describe "EmbeddingsUpsertBatch.perform/1" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    test "inserts a batch of record embeddings" do
      data_structure_version = insert(:data_structure_version)
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

      assert :ok =
               perform_job(EmbeddingsUpsertBatch, %{
                 data_structure_ids: [data_structure_version.data_structure_id]
               })

      assert [record_embedding] = Repo.all(RecordEmbedding)
      assert record_embedding.collection == "default"
      assert record_embedding.embedding == [-2.0, 2.0, 3.0]
      assert record_embedding.dims == 3
    end
  end
end
