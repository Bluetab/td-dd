defmodule TdCx.SourcesTest do
  use TdDd.DataCase

  alias TdCx.Sources
  alias TdCx.Sources.Source

  @valid_attrs %{
    "config" => %{"a" => "1"},
    "external_id" => "some external_id",
    "secrets_key" => "some secrets_key",
    "type" => "template_type",
    "active" => true
  }
  @update_attrs %{"config" => %{"a" => "2"}, "active" => false}
  @invalid_attrs %{"config" => 2, "external_id" => nil, "secrets_key" => nil, "type" => nil}
  @template %{
    id: 1,
    name: "template_type",
    label: "template_type",
    scope: "cx",
    content: [
      %{
        "name" => "New Group 1",
        "fields" => [
          %{
            "name" => "a",
            "type" => "string",
            "label" => "a",
            "widget" => "string",
            "cardinality" => "1"
          }
        ]
      }
    ]
  }

  setup do
    [template: Templates.create_template(@template)]
  end

  describe "Sources.get_source/1" do
    test "returns nil if params is nil" do
      assert Sources.get_source(nil) == nil
    end

    test "gets source by content alias if exists" do
      insert(:source)
      insert(:source, config: %{alias: "foo"})
      %{id: id, config: config} = insert(:source, config: %{"alias" => "bar"})
      assert %{id: ^id, config: ^config} = Sources.get_source(%{alias: "bar"})
    end
  end

  describe "sources" do
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

      {:ok, src1} =
        Sources.create_source(%{
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

      {:ok, src1} =
        Sources.create_source(%{
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
      %{id: source_id, external_id: external_id} = source = source_fixture()
      %{id: job_id} = insert(:job, source: source)

      assert %Source{id: ^source_id, jobs: jobs} =
               Sources.get_source!(external_id: external_id, preload: :jobs)

      assert [%{id: ^job_id}] = jobs
    end

    test "create_source/1 with valid data creates a source" do
      assert {:ok, %Source{} = source} = Sources.create_source(@valid_attrs)
      assert source.config == %{"a" => "1"}
      assert source.external_id == "some external_id"
      # assert source.secrets_key == "some secrets_key"
      assert source.type == "template_type"
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

    test "create_or_update_source/1 with valid data creates a source or updates it if deleted" do
      attrs = Map.put(@valid_attrs, "external_id", "ex1")
      assert {:ok, %Source{} = source} = Sources.create_or_update_source(attrs)
      assert source.config == Map.get(attrs, "config")
      assert source.external_id == Map.get(attrs, "external_id")
      assert source.secrets_key == Map.get(attrs, "secrets_key")
      assert source.type == Map.get(attrs, "type")
      attrs = Map.merge(attrs, @update_attrs)

      assert {:error, %Ecto.Changeset{errors: [external_id: {"has already been taken", _}]}} =
               Sources.create_or_update_source(attrs)

      {:ok, %Source{}} = Sources.update_source(source, %{deleted_at: DateTime.utc_now()})
      assert {:ok, %Source{} = source} = Sources.create_or_update_source(attrs)
      assert source.config == Map.get(attrs, "config")
      assert source.external_id == Map.get(attrs, "external_id")
      # Empty secrets in config
      assert source.secrets_key == nil
      assert source.type == Map.get(attrs, "type")
    end

    test "job_types/0 with valid an invalid data" do
      claims = build(:cx_claims)
      source = insert(:source, config: %{"job_types" => ["catalog"]})
      assert ["catalog"] = Sources.job_types(claims, source)

      source = insert(:source, config: %{"a" => "1"})
      assert [] = Sources.job_types(claims, source)

      source = insert(:source, config: %{"job_types" => nil})
      assert [] = Sources.job_types(claims, source)
    end
  end

  describe "Source.get_aliases/1" do
    test "returns an empty list if the source_id has no aliases" do
      %{id: source_id} = insert(:source, config: %{})
      assert Sources.get_aliases(source_id) == []
    end

    test "obtains the alias of a source specified by id" do
      %{id: source_id} = insert(:source, config: %{"alias" => "foo"})
      assert Sources.get_aliases(source_id) == ["foo"]
    end

    test "obtains the aliases of a source specified by id" do
      %{id: source_id} = insert(:source, config: %{"aliases" => ["foo", "bar"]})
      assert Sources.get_aliases(source_id) == ["foo", "bar"]
    end
  end

  describe "Sources.query_sources/1" do
    test "returns a list of sources" do
      insert(:source)
      insert(:source, config: %{alias: "foo"})

      %{id: id, config: config} =
        insert(:source, config: %{"alias" => "bar", "job_types" => ["profile"]})

      assert [%{id: ^id, config: ^config}] =
               Sources.query_sources(%{alias: "bar", job_types: "profile"})

      %{id: id, config: config} = insert(:source, config: %{"aliases" => ["foo"]})

      assert [%{id: ^id, config: ^config}] = Sources.query_sources(%{aliases: "foo"})

      assert [] = Sources.query_sources(%{alias: "baz"})
    end
  end

  defp source_fixture(attrs \\ %{}) do
    {:ok, source} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Sources.create_source()

    source
  end
end
