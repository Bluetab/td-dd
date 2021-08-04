defmodule TdDd.DataStructures.DataStructureVersionTest do
  use TdDd.DataCase

  alias Elasticsearch.Document
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
  end

  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
