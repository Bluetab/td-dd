defmodule TdDd.Search.EnricherImplTest do
  use TdDd.DataCase

  alias TdDd.Search.EnricherImpl
  alias TdDd.Search.StructureEnricher

  @moduletag sandbox: :shared

  setup do
    %{id: parent_id} = parent_domain = CacheHelpers.insert_domain()
    domain = CacheHelpers.insert_domain(%{parent_id: parent_id})

    %{id: template_id, name: template_name} =
      template =
      CacheHelpers.insert_template(
        scope: "dd",
        content: [
          build(:template_group,
            fields: [
              build(:template_field, name: "string"),
              build(:template_field,
                name: "list",
                type: "list",
                values: %{"fixed" => ["one", "two", "three"]}
              ),
              build(:template_field,
                name: "url",
                type: "url",
                cardinality: "*",
                widget: "pair_list"
              )
            ]
          )
        ]
      )

    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    # insert template and structure type
    start_supervised!(StructureEnricher)
    [domain: domain, template: template, parent_domain: parent_domain]
  end

  describe "enrich_versions/3" do
    test "enriches a chunk of structure ids", %{
      template: %{name: template_name},
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id}
    } do
      relation_type_id = 1
      valid_content = %{"string" => "initial", "list" => "one", "url" => nil}

      note =
        insert(:structure_note,
          df_content: Map.put(valid_content, "foo", "bar"),
          status: :published
        )

      data_structure = insert(:data_structure, published_note: note, domain_ids: [domain_id])
      dsv = insert(:data_structure_version, type: template_name, data_structure: data_structure)
      record_embedding = insert(:record_embedding, data_structure_version: dsv)

      assert [version] = EnricherImpl.enrich_versions([dsv.id], relation_type_id, %{})

      assert [%{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id}] =
               version.data_structure.domains

      assert version.data_structure.search_content == valid_content
      assert [embedding] = version.record_embeddings
      assert embedding.collection == record_embedding.collection
      assert embedding.embedding == record_embedding.embedding
      assert embedding.dims == record_embedding.dims
    end

    test "enriches with empty ids returns empty list" do
      relation_type_id = 1

      result = EnricherImpl.enrich_versions([], relation_type_id, %{})

      assert result == []
    end

    test "enriches multiple versions", %{
      template: %{name: template_name},
      domain: %{id: domain_id}
    } do
      data_structure1 = insert(:data_structure, domain_ids: [domain_id])
      dsv1 = insert(:data_structure_version, type: template_name, data_structure: data_structure1)

      data_structure2 = insert(:data_structure, domain_ids: [domain_id])
      dsv2 = insert(:data_structure_version, type: template_name, data_structure: data_structure2)

      relation_type_id = 1

      result = EnricherImpl.enrich_versions([dsv1.id, dsv2.id], relation_type_id, %{})

      assert length(result) == 2
      assert Enum.any?(result, &(&1.id == dsv1.id))
      assert Enum.any?(result, &(&1.id == dsv2.id))
    end

    test "enriches with filters", %{template: %{name: template_name}, domain: %{id: domain_id}} do
      data_structure = insert(:data_structure, domain_ids: [domain_id])
      dsv = insert(:data_structure_version, type: template_name, data_structure: data_structure)

      relation_type_id = 1
      filters = %{status: ["current"]}

      result = EnricherImpl.enrich_versions([dsv.id], relation_type_id, filters)

      assert is_list(result)
    end
  end

  describe "async_enrich_versions/3" do
    test "enriches versions asynchronously", %{
      template: %{name: template_name},
      domain: %{id: domain_id}
    } do
      data_structure = insert(:data_structure, domain_ids: [domain_id])
      dsv = insert(:data_structure_version, type: template_name, data_structure: data_structure)

      relation_type_id = 1
      chunked_stream = [[dsv.id]]

      result =
        chunked_stream
        |> EnricherImpl.async_enrich_versions(relation_type_id, %{})
        |> Enum.to_list()

      assert [enriched | _] = result
      assert enriched.id == dsv.id
    end

    test "processes multiple chunks", %{
      template: %{name: template_name},
      domain: %{id: domain_id}
    } do
      data_structure1 = insert(:data_structure, domain_ids: [domain_id])
      dsv1 = insert(:data_structure_version, type: template_name, data_structure: data_structure1)

      data_structure2 = insert(:data_structure, domain_ids: [domain_id])
      dsv2 = insert(:data_structure_version, type: template_name, data_structure: data_structure2)

      relation_type_id = 1
      chunked_stream = [[dsv1.id], [dsv2.id]]

      result =
        chunked_stream
        |> EnricherImpl.async_enrich_versions(relation_type_id, %{})
        |> Enum.to_list()

      assert length(result) == 2
      assert Enum.any?(result, &(&1.id == dsv1.id))
      assert Enum.any?(result, &(&1.id == dsv2.id))
    end

    test "handles empty stream" do
      relation_type_id = 1
      chunked_stream = []

      result =
        chunked_stream
        |> EnricherImpl.async_enrich_versions(relation_type_id, %{})
        |> Enum.to_list()

      assert result == []
    end
  end
end
