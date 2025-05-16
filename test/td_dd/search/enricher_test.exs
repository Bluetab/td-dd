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

      assert [version] = EnricherImpl.enrich_versions([dsv.id], relation_type_id, %{})

      assert [%{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id}] =
               version.data_structure.domains

      assert version.data_structure.search_content == valid_content
    end
  end
end
