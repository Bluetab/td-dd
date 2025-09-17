defmodule TdDd.DataStructures.DataStructureVersions.RecordEmbeddingTest do
  use TdDd.DataStructureCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.Repo

  @dims_samples [3, 128, 256, 512]

  describe "RecordEmbedding.changeset/2" do
    test "validates embeddings of different dims" do
      version_id = 1
      insert(:data_structure_version, id: version_id)

      for dims <- @dims_samples do
        vector = random_embedding(dims)

        assert %Changeset{valid?: true} =
                 changeset =
                 RecordEmbedding.changeset(%RecordEmbedding{}, %{
                   data_structure_version_id: version_id,
                   collection: "collection_#{dims}",
                   dims: dims,
                   embedding: vector
                 })

        assert {:ok, %RecordEmbedding{dims: inserted_dims, embedding: inserted_embedding}} =
                 Repo.insert(changeset)

        assert inserted_dims == dims
        assert inserted_embedding == vector
        assert length(inserted_embedding) == dims
      end
    end
  end

  defp random_embedding(dims) when is_integer(dims) and dims > 0 do
    Enum.map(1..dims, fn _ -> :rand.uniform() end)
  end
end
