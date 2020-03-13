defmodule TdDd.DataStructuresTest do
  use TdDd.DataStructureCase

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.RelationTypes

  import TdDd.TestOperators

  describe "data_structures" do
    @valid_attrs %{
      "description" => "some description",
      "group" => "some group",
      "last_change_by" => 42,
      "name" => "some name",
      "external_id" => "some external_id",
      "metadata" => %{},
      "system_id" => 1
    }
    @update_attrs %{
      # description: "some updated description",
      df_content: %{updated: "content"}
    }
    @invalid_attrs %{
      description: nil,
      group: nil,
      last_change_by: nil,
      name: nil
    }

    test "list_data_structures/1 returns all data_structures" do
      data_structure = insert(:data_structure)
      assert DataStructures.list_data_structures() <~> [data_structure]
    end

    test "list_data_structures/1 returns all data_structures from a search" do
      data_structure = insert(:data_structure)
      search_params = %{external_id: [data_structure.external_id]}

      assert DataStructures.list_data_structures(search_params), [data_structure]
    end

    test "get_data_structure!/1 returns the data_structure with given id" do
      data_structure = insert(:data_structure)
      assert DataStructures.get_data_structure!(data_structure.id) <~> data_structure
    end

    test "get_data_structure_by_external_id/1 returns the data_structure with metadata versions" do
      data_structure = insert(:data_structure)

      assert DataStructures.get_data_structure_by_external_id(data_structure.external_id)
             <~> data_structure
    end

    test "get_latest_metadata_version/1 returns the latest version of the metadata" do
      data_structure = insert(:data_structure)

      ms =
        Enum.map(
          0..5,
          &insert(:structure_metadata, version: &1, data_structure_id: data_structure.id)
        )

      assert DataStructures.get_latest_metadata_version(data_structure.id).id ==
               Enum.max_by(ms, & &1.version).id
    end

    test "get_latest_metadata_version/1 returns nil when there is not metadata" do
      data_structure = insert(:data_structure)
      assert is_nil(DataStructures.get_latest_metadata_version(data_structure.id))
    end

    test "get_data_structure!/1 returns error when structure does not exist" do
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_structure!(1) end
    end

    test "create_data_structure/1 with valid data creates a data_structure" do
      assert {:ok, %DataStructure{} = data_structure} =
               DataStructures.create_data_structure(@valid_attrs)

      assert data_structure.last_change_by == 42
      assert data_structure.system.external_id == "System_ref"
    end

    test "create_data_structure/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_data_structure(@invalid_attrs)
    end

    test "update_data_structure/2 with valid data updates the data_structure" do
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure_id: data_structure.id)

      assert {:ok, data_structure} =
               DataStructures.update_data_structure(data_structure, @update_attrs)

      assert %DataStructure{} = data_structure
      assert data_structure.df_content == %{updated: "content"}
    end

    test "delete_data_structure/1 deletes the data_structure" do
      data_structure = insert(:data_structure)
      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(data_structure)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure!(data_structure.id)
      end
    end

    test "find_data_structure/1 returns a data structure" do
      %{id: id, external_id: external_id} = insert(:data_structure)
      result = DataStructures.find_data_structure(%{external_id: external_id})

      assert %DataStructure{} = result
      assert result.id == id
      assert result.external_id == external_id
    end

    test "put_domain_id/3 with domain_name" do
      data = %{"domain_id" => :foo}
      domain_map = %{"foo" => :bar}
      assert %{"domain_id" => :bar} = DataStructures.put_domain_id(data, domain_map, "foo")
      assert %{"domain_id" => :foo} = DataStructures.put_domain_id(data, nil, "foo")
    end

    test "put_domain_id/3 with ou and/or domain_external_id" do
      import DataStructures, only: [put_domain_id: 3]
      ous = %{"foo" => :foo}
      ids = %{"bar" => :bar}

      assert %{"domain_id" => :baz} =
               put_domain_id(%{"domain_id" => :baz, "ou" => "foo"}, ous, ids)

      assert %{"domain_id" => :foo} = put_domain_id(%{"domain_id" => "", "ou" => "foo"}, ous, ids)
      assert %{"domain_id" => :foo} = put_domain_id(%{"ou" => "foo"}, ous, ids)

      assert %{"domain_id" => :bar} =
               put_domain_id(%{"domain_external_id" => "bar", "ou" => "foo"}, ous, ids)

      assert %{"domain_id" => :bar} =
               put_domain_id(
                 %{"domain_id" => "", "domain_external_id" => "bar", "ou" => "foo"},
                 ous,
                 ids
               )

      refute %{"domain_external_id" => "foo", "ou" => "bar"}
             |> put_domain_id(ous, ids)
             |> Map.has_key?("domain_id")
    end
  end

  describe "data structure versions" do
    test "get_siblings/1 returns sibling structure versions" do
      [ds1, ds2, ds3, ds4] =
        1..4
        |> Enum.map(
          &insert(
            :data_structure,
            external_id: "DS#{&1}",
            system_id: 1
          )
        )

      [dsv1, dsv2, dsv3, dsv4] =
        [ds1, ds2, ds3, ds4]
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, name: &1.external_id)
        )

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      [{dsv1, dsv2}, {dsv1, dsv3}, {dsv2, dsv4}, {dsv3, dsv4}]
      |> Enum.map(fn {parent, child} ->
        insert(:data_structure_relation,
          parent_id: parent.id,
          child_id: child.id,
          relation_type_id: default_relation_type_id
        )
      end)

      assert DataStructures.get_siblings(dsv1) == []
      assert DataStructures.get_siblings(dsv2) <|> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv3) <|> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv4) <|> [dsv4]
    end

    test "delete_data_structure/1 deletes a data_structure with relations" do
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv2.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv3.id,
        relation_type_id: default_relation_type_id
      )

      assert {:ok, %DataStructure{}} = DataStructures.delete_data_structure(ds1)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure!(ds1.id)
      end

      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end

    test "get_data_structure_version!/2 enriches with parents, children, siblings and relations" do
      [dsv, parent, child, sibling] =
        ["structure", "parent", "child", "sibling"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: default_relation_type_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents <|> [parent]
      assert children <|> [child]
      assert siblings <|> [sibling, dsv]
      assert relations.parents == []
      assert relations.children == []
    end

    test "get_data_structure_version!/1 returns the data_structure with given id" do
      data_structure_version = insert(:data_structure_version)

      assert DataStructures.get_data_structure_version!(data_structure_version.id)
             <~> data_structure_version
    end

    test "get_data_structure_version!/2 excludes deleted children if structure is not deleted" do
      [dsv, child, deleted_child] =
        ["structure", "child", "deleted_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, deleted_at: deleted_at(&1))
        )

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: deleted_child.id,
        relation_type_id: default_relation_type_id
      )

      assert %{children: children} =
               DataStructures.get_data_structure_version!(dsv.id, [:children])

      assert children <|> [child]
    end

    test "get_data_structure_version!/2 gets custom relations" do
      [
        dsv,
        parent,
        parent_custom_relation,
        child,
        child_custom_relation,
        sibling,
        sibling_custom_relation
      ] =
        [
          "structure",
          "parent",
          "parent_custom_relation",
          "child",
          "child_custom_relation",
          "sibling",
          "sibling_custom_relation"
        ]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      custom = insert(:relation_type, name: "relation_type_1")
      default_relation_type_id = RelationTypes.get_default_relation_type().id

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent_custom_relation.id,
        child_id: dsv.id,
        relation_type_id: custom.id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: default_relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling_custom_relation.id,
        relation_type_id: custom.id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child_custom_relation.id,
        relation_type_id: custom.id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: default_relation_type_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents <|> [parent]
      assert children <|> [child]
      assert siblings <|> [sibling, dsv]
      assert Enum.map(relations.parents, & &1.version) <|> [parent_custom_relation]
      assert Enum.map(relations.children, & &1.version) <|> [child_custom_relation]
    end

    defp deleted_at(%{external_id: "deleted_child"}), do: DateTime.utc_now()
    defp deleted_at(_), do: nil

    test "get_data_structure_version!/2 includes deleted children if structure is deleted" do
      [dsv | deleted_children] =
        ["structure", "child", "child2"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(
          &insert(:data_structure_version,
            data_structure_id: &1.id,
            deleted_at: DateTime.utc_now()
          )
        )

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      deleted_children
      |> Enum.each(
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: default_relation_type_id
        )
      )

      assert %{children: children} =
               DataStructures.get_data_structure_version!(dsv.id, [:children])

      assert children <|> deleted_children
    end

    test "get_data_structure_version!/2 enriches with fields" do
      [dsv | fields] =
        ["structure", "field1", "field2", "field3"]
        |> Enum.map(&insert(:data_structure, external_id: "get_data_structure_version!/2 " <> &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      default_relation_type_id = RelationTypes.get_default_relation_type().id

      Enum.map(
        fields,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: default_relation_type_id
        )
      )

      assert %{data_fields: data_fields} =
               DataStructures.get_data_structure_version!(dsv.id, [:data_fields])

      assert data_fields <|> fields
    end

    test "get_data_structure_version!/2 enriches with versions" do
      ds = insert(:data_structure, external_id: "get_data_structure_version!/2 versioned")

      [dsv | dsvs] =
        0..3
        |> Enum.map(&insert(:data_structure_version, data_structure_id: ds.id, version: &1))

      assert %{versions: versions} =
               DataStructures.get_data_structure_version!(dsv.id, [:versions])

      assert versions <|> [dsv | dsvs]
    end

    test "get_data_structure_version!/2 enriches with system" do
      sys = insert(:system, external_id: "foo")

      ds =
        insert(:data_structure,
          external_id: "get_data_structure_version!/2 system",
          system_id: sys.id
        )

      dsv = insert(:data_structure_version, data_structure_id: ds.id)

      assert %{system: system} = DataStructures.get_data_structure_version!(dsv.id, [:system])

      assert system == sys
    end

    test "get_data_structure_version!/2 enriches with domain" do
      domain = domain_fixture()
      ds = insert(:data_structure, domain_id: domain.id)
      dsv = insert(:data_structure_version, data_structure_id: ds.id)
      assert %{domain: d} = DataStructures.get_data_structure_version!(dsv.id, [:domain])

      assert domain.id == d.id
      assert domain.name == d.name
    end

    test "get_data_structure_version!/2 enriches with empty domain when there is not domain id" do
      ds = insert(:data_structure)
      dsv = insert(:data_structure_version, data_structure_id: ds.id)
      assert %{domain: %{}} = DataStructures.get_data_structure_version!(dsv.id, [:domain])
    end

    test "get_data_structure_version!/2 enriches with ancestry and path" do
      dsvs = create_hierarchy(["foo", "bar", "baz", "xyzzy"])

      [child | parents] = dsvs |> Enum.reverse()

      assert %{ancestry: ancestry, path: path} =
               DataStructures.get_data_structure_version!(child.id, [:ancestry, :path])

      assert ancestry <~> parents
      assert path == ["foo", "bar", "baz"]
    end

    test "get_latest_version_by_external_id/2 obtains the latest version of a structure" do
      external_id = "get_latest_version_by_external_id/2"
      ts = DateTime.utc_now()
      ds = insert(:data_structure, external_id: external_id)

      insert(:data_structure_version, data_structure_id: ds.id, version: 0, deleted_at: ts)
      insert(:data_structure_version, data_structure_id: ds.id, version: 1)
      v2 = insert(:data_structure_version, data_structure_id: ds.id, version: 2)
      v3 = insert(:data_structure_version, data_structure_id: ds.id, version: 3, deleted_at: ts)

      assert DataStructures.get_latest_version_by_external_id(external_id) <~> v3
      assert DataStructures.get_latest_version_by_external_id(external_id, deleted: false) <~> v2
    end

    test "get_ancestors/2 obtains all ancestors of a data structure version" do
      [child | ancestors] =
        ["foo", "bar", "baz", "xyzzy"]
        |> create_hierarchy()
        |> Enum.reverse()

      assert DataStructures.get_ancestors(child) <~> ancestors
    end

    test "get_descendents/2 obtains all descendents of a data structure version" do
      [parent | descendents] =
        ["foo", "bar", "baz", "xyzzy"]
        |> create_hierarchy()

      assert DataStructures.get_descendents(parent) <~> descendents
    end

    defp domain_fixture do
      domain_name = "domain_name"
      domain_id = :random.uniform(1_000_000)
      TaxonomyCache.put_domain(%{name: domain_name, id: domain_id})

      %{id: domain_id, name: domain_name}
    end
  end

  describe "profiles" do
    alias TdDd.DataStructures.Profile

    @valid_attrs %{value: %{}, data_structure_id: 0}
    @update_attrs %{value: %{"foo" => "bar"}}
    @invalid_attrs %{value: nil, data_structure_id: nil}

    defp profile_fixture do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)
      {:ok, structure} = DataStructures.create_profile(attrs)

      structure
    end

    test "get_profile!/1 gets the profile" do
      profile = profile_fixture()
      assert profile.id == DataStructures.get_profile!(profile.id).id
    end

    test "create_profile/1 with valid attrs creates the profile" do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)

      assert {:ok, %Profile{value: value, data_structure_id: ds_id}} =
               DataStructures.create_profile(attrs)

      assert ds.id == ds_id
      assert attrs.value == value
    end

    test "create_profile/1 with invalid attrs returns an error" do
      assert {:error, %Ecto.Changeset{}} = DataStructures.create_profile(@invalid_attrs)
    end

    test "update_profile/1 with valid attrs updates the profile" do
      profile = profile_fixture()

      assert {:ok, %Profile{value: value}} = DataStructures.update_profile(profile, @update_attrs)
      assert @update_attrs.value == value
    end
  end

  describe "structure_metadata" do
    alias TdDd.DataStructures.StructureMetadata

    @valid_attrs %{fields: %{}, data_structure_id: 0, version: 0}
    @update_attrs %{fields: %{"foo" => "bar"}, version: 0}
    @invalid_attrs %{fields: nil, data_structure_id: nil, version: nil}

    defp structure_metadata_fixture do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)
      {:ok, structure_metadata} = DataStructures.create_structure_metadata(attrs)

      structure_metadata
    end

    test "get_structure_metadata!/1 gets the metadata" do
      structure_metadata = structure_metadata_fixture()

      assert structure_metadata.id ==
               DataStructures.get_structure_metadata!(structure_metadata.id).id
    end

    test "create_structure_metadata/1 with valid attrs creates the metadata" do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)

      assert {:ok, %StructureMetadata{fields: fields, data_structure_id: ds_id, version: version}} =
               DataStructures.create_structure_metadata(attrs)

      assert ds.id == ds_id
      assert attrs.fields == fields
      assert attrs.version == version
    end

    test "create_structure_metadata/1 with invalid attrs returns an error" do
      assert {:error, %Ecto.Changeset{}} =
               DataStructures.create_structure_metadata(@invalid_attrs)
    end

    test "update_structure_metadata/1 with valid attrs updates the metadata" do
      ds = insert(:data_structure)
      mm = insert(:structure_metadata, data_structure: ds)

      assert {:ok, %StructureMetadata{fields: fields, data_structure_id: ds_id, version: version}} =
               DataStructures.update_structure_metadata(mm, @update_attrs)

      assert ds.id == ds_id
      assert @update_attrs.fields == fields
      assert @update_attrs.version == version
    end
  end
end
