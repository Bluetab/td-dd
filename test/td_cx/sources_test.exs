defmodule TdCx.SourcesTest do
  use TdCx.DataCase

  alias TdCx.Sources

  describe "sources" do
    alias TdCx.Sources.Source

    @valid_attrs %{config: [], external_id: "some external_id", secrets: [], type: "some type"}
    @update_attrs %{config: [], external_id: "some updated external_id", secrets: [], type: "some updated type"}
    @invalid_attrs %{config: nil, external_id: nil, secrets: nil, type: nil}

    def source_fixture(attrs \\ %{}) do
      {:ok, source} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sources.create_source()

      source
    end

    test "list_sources/0 returns all sources" do
      source = source_fixture()
      assert Sources.list_sources() == [source]
    end

    test "get_source!/1 returns the source with given id" do
      source = source_fixture()
      assert Sources.get_source!(source.id) == source
    end

    test "create_source/1 with valid data creates a source" do
      assert {:ok, %Source{} = source} = Sources.create_source(@valid_attrs)
      assert source.config == []
      assert source.external_id == "some external_id"
      assert source.secrets == []
      assert source.type == "some type"
    end

    test "create_source/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_attrs)
    end

    test "update_source/2 with valid data updates the source" do
      source = source_fixture()
      assert {:ok, %Source{} = source} = Sources.update_source(source, @update_attrs)
      assert source.config == []
      assert source.external_id == "some updated external_id"
      assert source.secrets == []
      assert source.type == "some updated type"
    end

    test "update_source/2 with invalid data returns error changeset" do
      source = source_fixture()
      assert {:error, %Ecto.Changeset{}} = Sources.update_source(source, @invalid_attrs)
      assert source == Sources.get_source!(source.id)
    end

    test "delete_source/1 deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Sources.get_source!(source.id) end
    end

    test "change_source/1 returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Sources.change_source(source)
    end
  end
end
