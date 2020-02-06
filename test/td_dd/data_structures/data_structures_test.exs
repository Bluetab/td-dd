defmodule TdDd.DataStructuresTest do
  use TdDd.DataStructureCase

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
      search_params = %{ou: [data_structure.ou]}

      assert DataStructures.list_data_structures(search_params), [data_structure]
    end

    test "get_data_structure!/1 returns the data_structure with given id" do
      data_structure = insert(:data_structure)
      assert DataStructures.get_data_structure!(data_structure.id) <~> data_structure
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

    test "add_domain_id/3" do
      data = %{"id" => 3, "name" => "structure", "ou" => "domain_2"}
      domain_map = %{"domain_1" => 1, "domain_2" => 2}
      domain_name = "domain_1"

      result = DataStructures.add_domain_id(data, domain_map, domain_name)

      assert result == %{"id" => 3, "name" => "structure", "ou" => "domain_1", "domain_id" => 1}
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
end
