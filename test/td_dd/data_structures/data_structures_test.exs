defmodule TdDd.DataStructuresTest do
  use TdDd.DataStructureCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.StructureTypeCache
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

    [template_name: template_name, claims: build(:claims)]
  end

  setup %{template_name: template_name} do
    alias TdCache.{ConceptCache, LinkCache}

    concept = %{id: "LINKED_CONCEPT", name: "concept"}
    system = insert(:system, external_id: "test_system")
    valid_content = %{"string" => "initial", "list" => "one"}
    data_structure = insert(:data_structure, system_id: system.id, df_content: valid_content)

    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: template_name)

    {:ok, _} = ConceptCache.put(concept)
    %{id: template_id, name: template_name} = template = build(:template, name: template_name)
    {:ok, _} = TemplateCache.put(template)

    %{id: structure_type_id} =
      structure_type =
      insert(:data_structure_type, structure_type: template_name, template_id: template_id)

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
      claims: claims
    } do
      params = %{df_content: %{"string" => "changed", "list" => "two"}}

      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.update_data_structure(data_structure, params, claims)

      assert %DataStructure{} = data_structure
      assert %{"list" => "two", "string" => "changed"} = data_structure.df_content
    end

    test "emits an audit event", %{data_structure: data_structure, claims: claims} do
      params = %{df_content: %{"string" => "changed", "list" => "two"}}

      assert {:ok, %{audit: event_id}} =
               DataStructures.update_data_structure(data_structure, params, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end
  end

  describe "delete_data_structure/2" do
    test "delete_data_structure/1 deletes the data_structure", %{
      data_structure: data_structure,
      claims: claims
    } do
      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.delete_data_structure(data_structure, claims)

      assert %{__meta__: %{state: :deleted}} = data_structure
    end

    test "emits an audit event", %{data_structure: data_structure, claims: claims} do
      assert {:ok, %{audit: event_id}} =
               DataStructures.delete_data_structure(data_structure, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "deletes a data_structure with relations", %{claims: claims} do
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
               DataStructures.delete_data_structure(ds1, claims)

      assert %{__meta__: %{state: :deleted}} = data_structure
      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end
  end

  describe "get_metadata_version/1" do
    test "returns the latest version of the metadata overlapping with the data structure version" do
      %{id: id} = insert(:data_structure)

      [dsv1, dsv2, dsv3] =
        [
          [inserted_at: ~U[2020-01-01 00:00:00Z], deleted_at: ~U[2020-02-01 00:00:00Z]],
          [inserted_at: ~U[2020-02-01 00:00:00Z], deleted_at: ~U[2020-03-01 00:00:00Z]],
          [inserted_at: ~U[2020-04-01 00:00:00Z]]
        ]
        |> Enum.with_index()
        |> Enum.map(fn {params, v} ->
          params |> Keyword.put(:data_structure_id, id) |> Keyword.put(:version, v)
        end)
        |> Enum.map(&insert(:data_structure_version, &1))

      [sm1, _sm2, sm3] =
        [
          [inserted_at: ~U[2020-02-02 00:00:00Z], deleted_at: ~U[2020-02-03 00:00:00Z]],
          [inserted_at: ~U[2020-03-02 00:00:00Z], deleted_at: ~U[2020-04-05 00:00:00Z]],
          [inserted_at: ~U[2020-05-01 00:00:00Z]]
        ]
        |> Enum.with_index()
        |> Enum.map(fn {params, v} ->
          params |> Keyword.put(:data_structure_id, id) |> Keyword.put(:version, v)
        end)
        |> Enum.map(&insert(:structure_metadata, &1))

      assert DataStructures.get_metadata_version(dsv1) == nil
      assert DataStructures.get_metadata_version(dsv2) == sm1
      assert DataStructures.get_metadata_version(dsv3) == sm3
    end
  end

  describe "get_latest_versions/1" do
    test "returns the latest version of each structure_id" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      for v <- Enum.shuffle(1..10) do
        insert(:data_structure_version, data_structure_id: id1, version: v)
        insert(:data_structure_version, data_structure_id: id2, version: v)
      end

      assert [%{version: 10}, %{version: 10}] =
               structures = DataStructures.get_latest_versions([id1, id2])

      assert [_, _] = structure_ids = Enum.map(structures, & &1.data_structure_id)
      assert id1 in structure_ids
      assert id2 in structure_ids
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

    test "get_structures_metadata_fields/1 will retrieve all metada fields of the filtered structures" do
      insert(:data_structure_version, type: "foo", metadata: %{"foo" => "value"})
      insert(:data_structure_version, type: "foo", metadata: %{"Foo" => "value"})
      insert(:data_structure_version, type: "foo", metadata: %{"bar" => "value"})
      insert(:data_structure_version, type: "bar", metadata: %{"xyz" => "value"})

      insert(:data_structure_version,
        type: "bar",
        metadata: %{"baz" => "value"},
        deleted_at: DateTime.utc_now()
      )

      assert [_ | _] =
               fields = DataStructures.get_structures_metadata_fields(%{type: ["foo", "bar"]})

      assert Enum.all?(["xyz", "Foo", "bar", "foo"], &(&1 in fields))
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

    test "delete_data_structure/1 deletes a data_structure with relations", %{claims: claims} do
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

      assert {:ok, %{} = reply} = DataStructures.delete_data_structure(ds1, claims)
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

    test "get_data_structure_version!/2 with options: tags" do
      d = insert(:data_structure)

      %{id: id1, description: d1, data_structure_tag: %{name: n1}} =
        insert(:data_structures_tags, data_structure: d, description: "foo")

      %{id: id2, description: d2, data_structure_tag: %{name: n2}} =
        insert(:data_structures_tags, data_structure: d, description: "bar")

      version = insert(:data_structure_version, data_structure: d)

      assert %{
               tags: [
                 %{id: ^id1, description: ^d1, data_structure_tag: %{name: ^n1}},
                 %{id: ^id2, description: ^d2, data_structure_tag: %{name: ^n2}}
               ]
             } = DataStructures.get_data_structure_version!(version.id, [:tags])
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
      domain = DomainHelper.insert_domain()
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

    test "get_path!/1 returns the names of the structures default ancestors" do
      [child | _] =
        ["foo", "bar", "baz", "xyzzy"]
        |> create_hierarchy()
        |> Enum.reverse()

      path =
        child.id
        |> DataStructures.get_data_structure_version!()
        |> DataStructures.get_path()

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

      path =
        c1.id
        |> DataStructures.get_data_structure_version!()
        |> DataStructures.get_path()

      assert path == ["dsv1", "dsv2"]
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

  describe "profile_source/1" do
    setup do
      s1 = insert(:source, config: %{"job_types" => ["catalog", "quality", "profile"]})
      s2 = insert(:source)
      s3 = insert(:source, config: %{"job_types" => ["catalog"], "alias" => "foo"})
      s4 = insert(:source, external_id: "foo", config: %{"job_types" => ["profile"]})

      v1 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s1))
      v2 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s2))
      v3 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s3))

      [sources: [s1, s2, s3, s4], versions: [v1, v2, v3]]
    end

    test "profile_source/1 when there are not related sources with profile", %{
      versions: [_, v, _]
    } do
      assert %{profile_source: nil} = DataStructures.profile_source(v)
    end

    test "profile_source/1 get profile source when is directly related to the data structure", %{
      versions: [v, _, _],
      sources: [%{external_id: external_id}, _, _, _]
    } do
      assert %{profile_source: %{external_id: ^external_id}} = DataStructures.profile_source(v)
    end

    test "profile_source/1 get profile source when is related to the data structure by source alias",
         %{
           versions: [_, _, v],
           sources: [_, _, s3, s4]
         } do
      %{external_id: s3_external_id} = s3
      %{external_id: s4_external_id} = s4

      assert %{
               data_structure: %{source: %{external_id: ^s3_external_id}},
               profile_source: %{external_id: ^s4_external_id}
             } = DataStructures.profile_source(v)
    end
  end

  describe "data_structure_tags" do
    alias TdDd.DataStructures.DataStructureTag

    @valid_attrs %{name: "some name"}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil}

    def data_structure_tag_fixture(attrs \\ %{}) do
      {:ok, data_structure_tag} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DataStructures.create_data_structure_tag()

      data_structure_tag
    end

    test "list_data_structure_tags/0 returns all data_structure_tags" do
      data_structure_tag = data_structure_tag_fixture()
      assert DataStructures.list_data_structure_tags() == [data_structure_tag]
    end

    test "list_data_structure_tags/1 returns all data_structure_tags with preloaded structures" do
      %{id: structure_id, external_id: external_id} = structure = insert(:data_structure)
      %{id: id, name: name} = structure_tag = insert(:data_structure_tag)
      insert(:data_structures_tags, data_structure: structure, data_structure_tag: structure_tag)

      assert [
               %{
                 id: ^id,
                 name: ^name,
                 tagged_structures: [%{id: ^structure_id, external_id: ^external_id}]
               }
             ] = DataStructures.list_data_structure_tags(preload: [:tagged_structures])
    end

    test "get_data_structure_tag!/1 returns the data_structure_tag with given id" do
      data_structure_tag = data_structure_tag_fixture()
      assert DataStructures.get_data_structure_tag!(data_structure_tag.id) == data_structure_tag
    end

    test "get_data_structure_tag!/1 returns the data_structure_tag with specified preloads by given id" do
      %{id: structure_id, external_id: external_id} = structure = insert(:data_structure)
      %{id: id, name: name} = structure_tag = insert(:data_structure_tag)
      insert(:data_structures_tags, data_structure: structure, data_structure_tag: structure_tag)

      assert %{
               id: ^id,
               name: ^name,
               tagged_structures: [%{id: ^structure_id, external_id: ^external_id}]
             } = DataStructures.get_data_structure_tag!(id, preload: [:tagged_structures])
    end

    test "create_data_structure_tag/1 with valid data creates a data_structure_tag" do
      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               DataStructures.create_data_structure_tag(@valid_attrs)

      assert data_structure_tag.name == "some name"
    end

    test "create_data_structure_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               DataStructures.create_data_structure_tag(@invalid_attrs)
    end

    test "update_data_structure_tag/2 with valid data updates the data_structure_tag" do
      data_structure_tag = data_structure_tag_fixture()

      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               DataStructures.update_data_structure_tag(data_structure_tag, @update_attrs)

      assert data_structure_tag.name == "some updated name"
    end

    test "update_data_structure_tag/2 with invalid data returns error changeset" do
      data_structure_tag = data_structure_tag_fixture()

      assert {:error, %Ecto.Changeset{}} =
               DataStructures.update_data_structure_tag(data_structure_tag, @invalid_attrs)

      assert data_structure_tag == DataStructures.get_data_structure_tag!(data_structure_tag.id)
    end

    test "delete_data_structure_tag/1 deletes the data_structure_tag" do
      data_structure_tag = data_structure_tag_fixture()

      assert {:ok, %DataStructureTag{}} =
               DataStructures.delete_data_structure_tag(data_structure_tag)

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure_tag!(data_structure_tag.id)
      end
    end
  end

  describe "link_tag/3" do
    test "links tag to a given structure" do
      description = "foo"
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id} = insert(:data_structure_tag)
      params = %{description: description}

      {:ok,
       %{
         description: ^description,
         data_structure: %{id: ^data_structure_id},
         data_structure_tag: %{id: ^tag_id}
       }} = DataStructures.link_tag(structure, tag, params)
    end

    test "updates link information when it already exists" do
      description = "bar"
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id} = insert(:data_structure_tag)

      insert(:data_structures_tags,
        data_structure_tag: tag,
        data_structure: structure,
        description: "foo"
      )

      params = %{description: description}

      {:ok,
       %{
         description: ^description,
         data_structure: %{id: ^data_structure_id},
         data_structure_tag: %{id: ^tag_id}
       }} = DataStructures.link_tag(structure, tag, params)
    end

    test "gets error when description is invalid" do
      structure = insert(:data_structure)
      tag = insert(:data_structure_tag)
      params = %{}

      {:error,
       %{errors: [description: {"can't be blank", [validation: :required]}], valid?: false}} =
        DataStructures.link_tag(structure, tag, params)

      params = %{description: nil}

      {:error,
       %{errors: [description: {"can't be blank", [validation: :required]}], valid?: false}} =
        DataStructures.link_tag(structure, tag, params)

      params = %{description: String.duplicate("foo", 334)}

      {:error,
       %{
         errors: [
           description:
             {"should be at most %{count} character(s)",
              [count: 1000, validation: :length, kind: :max, type: :string]}
         ],
         valid?: false
       }} = DataStructures.link_tag(structure, tag, params)
    end
  end

  describe "get_links_tag/2" do
    test "gets a list of links between a structure and its tags" do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: data_structure_tag_id, name: name} = insert(:data_structure_tag)

      %{id: link_id, description: description} =
        insert(:data_structures_tags, data_structure: structure, data_structure_tag: tag)

      assert [
               %{
                 id: ^link_id,
                 data_structure: %{id: ^data_structure_id},
                 data_structure_tag: %{id: ^data_structure_tag_id, name: ^name},
                 description: ^description
               }
             ] = DataStructures.get_links_tag(structure)
    end
  end

  describe "delete_link_tag/2" do
    test "deletes link between tag and structure" do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: data_structure_tag_id} = insert(:data_structure_tag)
      insert(:data_structures_tags, data_structure: structure, data_structure_tag: tag)

      assert {:ok,
              %{
                data_structure_id: ^data_structure_id,
                data_structure_tag_id: ^data_structure_tag_id
              }} = DataStructures.delete_link_tag(structure, tag)

      assert is_nil(DataStructures.get_link_tag_by(data_structure_id, data_structure_tag_id))
    end

    test "not_found if link does not exist" do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: data_structure_tag_id} = insert(:data_structure_tag)

      assert {:error, :not_found} = DataStructures.delete_link_tag(structure, tag)
      assert is_nil(DataStructures.get_link_tag_by(data_structure_id, data_structure_tag_id))
    end
  end
end
