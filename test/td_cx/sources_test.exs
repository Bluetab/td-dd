defmodule TdCx.SourcesTest do
  use TdCx.DataCase

  alias TdCx.Sources

  describe "sources" do
    alias TdCx.Sources.Source

    @valid_attrs %{"config" => %{"a" => "1"}, "external_id" => "some external_id", "secrets_key" => "some secrets_key", "type" => "app-admin", "active" => true}
    @update_attrs %{"config" => %{"a" => "2"}, "active" => false}
    @invalid_attrs %{"config" => 2, "external_id" => nil, "secrets_key" => nil, "type" => nil}
    @app_admin_template %{
      id: 1,
      name: "app-admin",
      label: "app-admin",
      scope: "cx",
      content: [%{
        "name" => "a",
        "type" => "string",
        "group" => "New Group 1",
        "label" => "a",
        "widget" => "string",
        "disabled" => true,
        "cardinality" => "1"
      }]
    }

    def source_fixture(attrs \\ %{}) do
      Templates.create_template(@app_admin_template)

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

    test "list_sources/1 with deleted false returns non deleted sources" do
      source = source_fixture()
      _s2 = source_fixture(%{"deleted_at" => "2018-11-14 09:31:07Z"})
      assert Sources.list_sources(deleted: false) == [source]
      assert length(Sources.list_sources()) == 2
    end

    test "list_sources_by_source_type/1 returns only sources of a type" do
      Templates.create_template(%{name: "type1", id: 2, content: [], scope: "cx"})
      Templates.create_template(%{name: "type2", id: 3, content: [], scope: "cx"})

      type = "type1"
      {:ok, src1} = Sources.create_source(%{
        "external_id" => "ext1",
        "type" => type,
        "secrets_key" => "s",
        "config" => %{}
      })
      Sources.create_source(%{
        "external_id" => "ext2",
        "type" => "type2",
        "secrets_key" => "s",
        "config" => %{}
      })

      assert length(Sources.list_sources()) == 2
      assert [^src1] = Sources.list_sources_by_source_type(type)
    end

    test "list_sources_by_source_type/1 returns only active sources" do
      type = "type1"
      Templates.create_template(%{name: type, id: 2, content: [], scope: "cx"})

      {:ok, src1} = Sources.create_source(%{
        "external_id" => "ext1",
        "type" => type,
        "secrets_key" => "s",
        "config" => %{}
      })
      Sources.create_source(%{
        "external_id" => "ext2",
        "type" => type,
        "secrets_key" => "s",
        "config" => %{},
        "active" => false
      })

      assert length(Sources.list_sources()) == 2
      assert [^src1] = Sources.list_sources_by_source_type(type)
    end

    test "get_source!/1 returns the source with given id" do
      source = source_fixture()
      assert Sources.get_source!(source.external_id) == source
    end

    test "get_source!/2 with jobs option with get source with its jobs" do
      source = source_fixture()
      job = insert(:job, source: source)
      options = [:jobs]
      assert %Source{id: id, jobs: jobs} = Sources.get_source!(source.external_id, options)
      assert id == source.id
      assert length(jobs) == 1
      assert Enum.any?(jobs, & &1.id == job.id)
    end

    test "create_source/1 with valid data creates a source" do
      assert {:ok, %Source{} = source} = Sources.create_source(@valid_attrs)
      assert source.config == %{"a" => "1"}
      assert source.external_id == "some external_id"
      #assert source.secrets_key == "some secrets_key"
      assert source.type == "app-admin"
    end

    test "create_source/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_attrs)
    end

    test "update_source/2 with valid data updates the source" do
      source = source_fixture()
      assert {:ok, %Source{} = source} = Sources.update_source(source, @update_attrs)
      assert source.config == %{"a" => "2"}
    end

    test "update_source/2 with invalid data returns error changeset" do
      source = source_fixture()
      assert {:error, %Ecto.Changeset{}} = Sources.update_source(source, @invalid_attrs)
      assert source == Sources.get_source!(source.external_id)
    end

    test "delete_source/1 deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Sources.get_source!(source.external_id) end
    end

    test "change_source/1 returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Sources.change_source(source)
    end
  end
end
