defmodule TdDd.Search.StructureEnricherTest do
  use TdDd.DataCase

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

  describe "StructureEnricher.refresh/1" do
    test "loads initial state" do
      assert :ok = StructureEnricher.refresh()
    end

    test "enriches the domain", %{
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id}
    } do
      assert %{domains: domains} =
               :data_structure
               |> insert(domain_ids: [domain_id])
               |> StructureEnricher.enrich()

      assert [%{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id}] = domains
    end

    test "enriches the linked concepts flag" do
      %{id: id} = structure = insert(:data_structure)
      assert %{linked_concepts: false} = StructureEnricher.enrich(structure)
      CacheHelpers.insert_link(id, "data_structure", "business_concept", nil)
      assert %{linked_concepts: true} = StructureEnricher.enrich(structure)
    end

    test "formats the content for search", %{template: %{name: template_name}} do
      valid_content = %{"string" => "initial", "list" => "one", "url" => nil}

      note = insert(:structure_note, df_content: Map.put(valid_content, "foo", "bar"))
      data_structure = insert(:data_structure, published_note: note)
      insert(:data_structure_version, type: template_name, data_structure: data_structure)

      assert %{search_content: search_content} =
               StructureEnricher.enrich(data_structure, template_name, :searchable)

      assert search_content == valid_content
    end
  end
end
