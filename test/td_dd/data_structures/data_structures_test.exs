defmodule TdDd.DataStructuresTest do
  use TdDd.DataStructureCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.StructureTypeCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.RelationTypes

  import TdDd.TestOperators

  @stream TdCache.Audit.stream()

  setup_all do
    %{id: template_id, name: template_name} = template = build(:template)
    {:ok, _} = TemplateCache.put(template)

    %{id: structure_type_id} =
      structure_type =
      build(:data_structure_type, structure_type: template_name, template_id: template_id)

    {:ok, _} = StructureTypeCache.put(structure_type)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      StructureTypeCache.delete(structure_type_id)
      Redix.del!(@stream)
    end)

    [template_name: template_name, user: build(:user)]
  end

  setup %{template_name: template_name} do
    alias TdCache.{ConceptCache, LinkCache, StructureCache, SystemCache}

    concept = %{id: "LINKED_CONCEPT", name: "concept"}
    system = insert(:system, external_id: "test_system")
    valid_content = %{"string" => "initial", "list" => "one"}
    data_structure = insert(:data_structure, system_id: system.id, df_content: valid_content)

    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: template_name)

    {:ok, _} = ConceptCache.put(concept)
    {:ok, _} = SystemCache.put(system)
    {:ok, _} = StructureCache.put(data_structure)
    %{id: template_id, name: template_name} = template = build(:template, name: template_name)
    {:ok, _} = TemplateCache.put(template)

    %{id: structure_type_id} =
      structure_type =
      build(:data_structure_type, structure_type: template_name, template_id: template_id)

    {:ok, _} = StructureTypeCache.put(structure_type)

    {:ok, _} =
      LinkCache.put(%{
        id: 123_456_789,
        updated_at: DateTime.utc_now(),
        source_type: "data_structure",
        source_id: data_structure.id,
        target_type: "business_concept",
        target_id: concept.id
      })

    on_exit(fn ->
      LinkCache.delete(123_456_789)
      StructureCache.delete(data_structure.id)
      SystemCache.delete(system.id)
      ConceptCache.delete(concept.id)
      TemplateCache.delete(template_id)
      StructureTypeCache.delete(structure_type_id)
    end)

    [
      data_structure: data_structure,
      data_structure_version: data_structure_version,
      system: system
    ]
  end

  describe "update_data_structure/3" do
    test "updates the data_structure with valid data", %{
      data_structure: data_structure,
      user: user
    } do
      params = %{df_content: %{"string" => "changed", "list" => "two"}}

      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.update_data_structure(data_structure, params, user)

      assert %DataStructure{} = data_structure
      assert %{"list" => "two", "string" => "changed"} = data_structure.df_content
    end

    test "emits an audit event", %{data_structure: data_structure, user: user} do
      params = %{df_content: %{"string" => "changed", "list" => "two"}}

      assert {:ok, %{audit: event_id}} =
               DataStructures.update_data_structure(data_structure, params, user)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end
  end

  describe "delete_data_structure/2" do
    test "delete_data_structure/1 deletes the data_structure", %{
      data_structure: data_structure,
      user: user
    } do
      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.delete_data_structure(data_structure, user)

      assert %{__meta__: %{state: :deleted}} = data_structure
    end

    test "emits an audit event", %{
      data_structure: data_structure,
      user: user
    } do
      assert {:ok, %{audit: event_id}} =
               DataStructures.delete_data_structure(data_structure, user)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "deletes a data_structure with relations", %{user: user} do
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv2.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv3.id,
        relation_type_id: relation_type_id
      )

      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.delete_data_structure(ds1, user)

      assert %{__meta__: %{state: :deleted}} = data_structure
      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end
  end

  describe "data_structures" do
    @update_attrs %{
      # description: "some updated description",
      df_content: %{"string" => "changed", "list" => "two"}
    }
    @invalid_attrs %{
      description: nil,
      group: nil,
      last_change_by: nil,
      name: nil
    }

    test "list_data_structures/1 returns all data_structures", %{data_structure: data_structure} do
      assert DataStructures.list_data_structures() <~> [data_structure]
    end

    test "list_data_structures/1 returns all data_structures from a search", %{
      data_structure: data_structure
    } do
      search_params = %{external_id: [data_structure.external_id]}

      assert DataStructures.list_data_structures(search_params), [data_structure]
    end

    test "get_data_structure!/1 returns the data_structure with given id", %{
      data_structure: data_structure
    } do
      assert DataStructures.get_data_structure!(data_structure.id) <~> data_structure
    end

    test "get_data_structure_by_external_id/1 returns the data_structure with metadata versions",
         %{data_structure: data_structure} do
      assert DataStructures.get_data_structure_by_external_id(data_structure.external_id)
             <~> data_structure
    end

    test "get_latest_metadata_version/2 returns the latest version of the metadata", %{
      data_structure: data_structure
    } do
      ms =
        Enum.map(
          0..5,
          &insert(:structure_metadata, version: &1, data_structure_id: data_structure.id)
        )

      assert DataStructures.get_latest_metadata_version(data_structure.id).id ==
               Enum.max_by(ms, & &1.version).id
    end

    test "get_latest_metadata_version/2 returns nil when there is not metadata", %{
      data_structure: data_structure
    } do
      assert is_nil(DataStructures.get_latest_metadata_version(data_structure.id))
    end

    test "get_latest_metadata_version/2 hides deleted versions when specified", %{
      data_structure: data_structure
    } do
      ms =
        insert(:structure_metadata,
          data_structure_id: data_structure.id,
          deleted_at: DateTime.utc_now()
        )

      assert is_nil(DataStructures.get_latest_metadata_version(data_structure.id, deleted: false))
      assert DataStructures.get_latest_metadata_version(data_structure.id).id == ms.id
    end

    test "get_data_structure!/1 returns error when structure does not exist" do
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_structure!(1) end
    end

    test "find_data_structure/1 returns a data structure", %{data_structure: data_structure} do
      %{id: id, external_id: external_id} = data_structure
      result = DataStructures.find_data_structure(%{external_id: external_id})

      assert %DataStructure{} = result
      assert result.id == id
      assert result.external_id == external_id
    end

    test "put_domain_id/3 with domain external id" do
      data = %{"domain_id" => :foo}
      domain_map = %{"foo" => :bar}
      assert %{"domain_id" => :bar} = DataStructures.put_domain_id(data, domain_map, "foo")
      assert %{"domain_id" => :foo} = DataStructures.put_domain_id(data, nil, "foo")
    end

    test "put_domain_id/2 with ou and/or domain_external_id" do
      import DataStructures, only: [put_domain_id: 2]
      ids = %{"bar" => :bar, "foo" => :foo}

      assert %{"domain_id" => :baz} = put_domain_id(%{"domain_id" => :baz, "ou" => "foo"}, ids)

      assert %{"domain_id" => :foo} = put_domain_id(%{"domain_id" => "", "ou" => "foo"}, ids)
      assert %{"domain_id" => :foo} = put_domain_id(%{"ou" => "foo"}, ids)

      assert %{"domain_id" => :bar} = put_domain_id(%{"domain_external_id" => "bar"}, ids)

      assert %{"domain_id" => :bar} =
               put_domain_id(
                 %{"domain_id" => "", "domain_external_id" => "bar"},
                 ids
               )

      refute %{"domain_external_id" => "baz", "ou" => "baz"}
             |> put_domain_id(ids)
             |> Map.has_key?("domain_id")
    end
  end

  describe "data structure versions" do
    test "get_siblings/1 returns sibling structure versions" do
      %{id: system_id} = insert(:system)

      [ds1, ds2, ds3, ds4] =
        1..4
        |> Enum.map(
          &insert(
            :data_structure,
            external_id: "DS#{&1}",
            system_id: system_id
          )
        )

      [dsv1, dsv2, dsv3, dsv4] =
        [ds1, ds2, ds3, ds4]
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, name: &1.external_id)
        )

      %{id: relation_type_id} = RelationTypes.get_default()

      [{dsv1, dsv2}, {dsv1, dsv3}, {dsv2, dsv4}, {dsv3, dsv4}]
      |> Enum.map(fn {parent, child} ->
        insert(:data_structure_relation,
          parent_id: parent.id,
          child_id: child.id,
          relation_type_id: relation_type_id
        )
      end)

      assert DataStructures.get_siblings(dsv1) == []
      assert DataStructures.get_siblings(dsv2) <|> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv3) <|> [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv4) <|> [dsv4]
    end

    test "delete_data_structure/1 deletes a data_structure with relations", %{
      user: user
    } do
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv2.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv3.id,
        relation_type_id: relation_type_id
      )

      assert {:ok, %{} = reply} = DataStructures.delete_data_structure(ds1, user)
      data_structure = Map.get(reply, :data_structure)

      assert %{__meta__: %{state: :deleted}} = data_structure

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

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
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

    test "get_data_structure_version!/2 with options: parents, children, siblings, with_confidential enriches including confidential" do
      [dsv, parent, child, sibling, r_child] =
        ["structure", "parent", "child", "sibling", "r_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      [child_confidential, sibling_confidential, r_child_confidential] =
        ["child_confidential", "sibling_confidential", "r_child_confidential"]
        |> Enum.map(&insert(:data_structure, external_id: &1, confidential: true))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      fields =
        ["field1", "field2", "field3"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      field_confidential =
        ["field4_confidential"]
        |> Enum.map(&insert(:data_structure, external_id: &1, confidential: true))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      %{id: relation_type_id} = RelationTypes.get_default()
      %{id: custom_relation_id} = insert(:relation_type, name: "relation_type_1")

      Enum.map(
        fields ++ field_confidential,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling_confidential.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: r_child.id,
        relation_type_id: custom_relation_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: r_child_confidential.id,
        relation_type_id: custom_relation_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child_confidential.id,
        relation_type_id: relation_type_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations, :data_fields]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations,
               data_fields: data_fields
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents <|> [parent]
      assert children <|> ([child] ++ fields)
      assert siblings <|> [sibling, dsv]
      assert data_fields <|> fields
      assert %{children: [child_relation]} = relations
      assert child_relation.version <~> r_child

      enrich_opts = [:parents, :children, :siblings, :with_confidential, :relations]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents <|> [parent]
      assert children <|> ([child, child_confidential] ++ fields ++ field_confidential)
      assert siblings <|> [sibling, dsv, sibling_confidential]
      assert %{children: child_rels} = relations
      assert Enum.find(child_rels, &(&1.version.id == r_child.id)).version <~> r_child

      assert Enum.find(child_rels, &(&1.version.id == r_child_confidential.id)).version
             <~> r_child_confidential
    end

    test "get_data_structure_version!/1 returns the data_structure with given id", %{
      data_structure_version: data_structure_version
    } do
      assert DataStructures.get_data_structure_version!(data_structure_version.id)
             <~> data_structure_version
    end

    test "get_data_structure_version!/2 excludes deleted children if structure is not deleted" do
      %{id: system_id} = insert(:system)

      [dsv, child, deleted_child] =
        ["structure", "child", "deleted_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1, system_id: system_id))
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, deleted_at: deleted_at(&1))
        )

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: deleted_child.id,
        relation_type_id: relation_type_id
      )

      assert %{children: children} =
               DataStructures.get_data_structure_version!(dsv.id, [:children])

      assert children <|> [child]
    end

    test "get_data_structure_version!/2 gets custom relations", %{
      data_structure_version: child_custom_relation
    } do
      [
        dsv,
        parent,
        parent_custom_relation,
        child,
        sibling
      ] =
        [
          "structure",
          "parent",
          "parent_custom_relation",
          "child",
          "sibling"
        ]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      %{id: custom_id} = insert(:relation_type, name: "relation_type_1")
      %{id: default_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: default_id
      )

      insert(:data_structure_relation,
        parent_id: parent_custom_relation.id,
        child_id: dsv.id,
        relation_type_id: custom_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: default_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child_custom_relation.id,
        relation_type_id: custom_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: default_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations, :relation_links]

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
      assert %{parents: [parent_relation], children: [child_relation]} = relations
      assert parent_relation.version <~> parent_custom_relation
      assert child_relation.version <~> child_custom_relation
      assert [link] = child_relation.links
      assert %{resource_type: :concept, resource_id: "LINKED_CONCEPT"} = link
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

      %{id: relation_type_id} = RelationTypes.get_default()

      deleted_children
      |> Enum.each(
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
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

      %{id: relation_type_id} = RelationTypes.get_default()

      Enum.map(
        fields,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      assert %{data_fields: data_fields} =
               DataStructures.get_data_structure_version!(dsv.id, [:data_fields])

      assert data_fields <|> fields
    end

    test "get_data_structure_version!/2 enriches with versions", %{system: system} do
      ds = insert(:data_structure, system_id: system.id)

      [dsv | dsvs] =
        0..3
        |> Enum.map(&insert(:data_structure_version, data_structure_id: ds.id, version: &1))

      assert %{versions: versions} =
               DataStructures.get_data_structure_version!(dsv.id, [:versions])

      assert versions <|> [dsv | dsvs]
    end

    test "get_data_structure_version!/2 enriches with system", %{
      data_structure_version: dsv,
      system: sys
    } do
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

    test "get_data_structure_version!/2 enriches with empty domain when there is not domain id",
         %{data_structure_version: dsv} do
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
      %{id: system_id} = insert(:system)
      external_id = "get_latest_version_by_external_id/2"
      ts = DateTime.utc_now()
      ds = insert(:data_structure, external_id: external_id, system_id: system_id)

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

    test "get_path/2 obtains all descendents of a data structure version" do
      %{id: system_id} = insert(:system)

      p =
        insert(:data_structure_version,
          name: "dsv1",
          data_structure: build(:data_structure, external_id: "dsv1", system_id: system_id)
        )

      p1 =
        insert(:data_structure_version,
          name: "dsv2",
          data_structure: build(:data_structure, external_id: "dsv2", system_id: system_id)
        )

      c1 =
        insert(:data_structure_version,
          name: "c1",
          data_structure: build(:data_structure, external_id: "c1", system_id: system_id)
        )

      versions =
        Enum.map(
          2..50,
          &insert(:data_structure_version,
            name: "c#{&1}",
            data_structure: build(:data_structure, external_id: "c#{&1}", system_id: system_id)
          )
        )

      %{id: default_type_id} = RelationTypes.get_default()
      %{id: custom_id} = insert(:relation_type, name: "relation_type_1")

      Enum.each(
        versions,
        &insert(:data_structure_relation,
          parent_id: &1.id,
          child_id: c1.id,
          relation_type_id: custom_id
        )
      )

      insert(:data_structure_relation,
        parent_id: p.id,
        child_id: p1.id,
        relation_type_id: default_type_id
      )

      insert(:data_structure_relation,
        parent_id: p1.id,
        child_id: c1.id,
        relation_type_id: default_type_id
      )

      assert DataStructures.get_path(c1) == ["dsv1", "dsv2"]
    end

    defp domain_fixture do
      domain_name = "domain_name"
      domain_id = :random.uniform(1_000_000)
      updated_at = DateTime.utc_now()
      TaxonomyCache.put_domain(%{name: domain_name, id: domain_id, updated_at: updated_at})

      %{id: domain_id, name: domain_name}
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

    test "create_structure_metadata/1 with valid attrs creates the metadata", %{
      data_structure: ds
    } do
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

    test "update_structure_metadata/1 with valid attrs updates the metadata", %{
      data_structure: ds
    } do
      mm = insert(:structure_metadata, data_structure: ds)

      assert {:ok, %StructureMetadata{fields: fields, data_structure_id: ds_id, version: version}} =
               DataStructures.update_structure_metadata(mm, @update_attrs)

      assert ds.id == ds_id
      assert @update_attrs.fields == fields
      assert @update_attrs.version == version
    end
  end
end
