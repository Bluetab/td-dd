defmodule TdDd.Search.StructureEnricherTest do
  use TdDd.DataCase

  alias TdDd.Search.StructureEnricher

  @moduletag sandbox: :shared

  setup do
    %{id: parent_id} = parent_domain = CacheHelpers.insert_domain()
    domain = CacheHelpers.insert_domain(%{parent_ids: [parent_id]})
    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()

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
      assert %{domain: domain} =
               :data_structure
               |> insert(domain_id: domain_id)
               |> StructureEnricher.enrich()

      assert %{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id} = domain
    end

    test "enriches the domain parents", %{
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id},
      parent_domain: %{id: parent_id, name: parent_name, external_id: parent_external_id}
    } do
      assert %{domain_parents: parents} =
               :data_structure
               |> insert(domain_id: domain_id)
               |> StructureEnricher.enrich()

      assert parents == [
               %{id: domain_id, external_id: domain_external_id, name: domain_name},
               %{id: parent_id, external_id: parent_external_id, name: parent_name}
             ]
    end

    test "enriches the link count" do
      %{id: id} = structure = insert(:data_structure)
      assert %{linked_concepts_count: 0} = StructureEnricher.enrich(structure)
      CacheHelpers.insert_link(id)
      assert %{linked_concepts_count: 1} = StructureEnricher.enrich(structure)
    end

    test "formats the content for search", %{template: %{name: template_name}} do
      valid_content = %{"string" => "initial", "list" => "one"}

      data_structure = insert(:data_structure, latest_note: Map.put(valid_content, "foo", "bar"))
      insert(:data_structure_version, type: template_name, data_structure: data_structure)

      assert %{search_content: search_content} =
               StructureEnricher.enrich(data_structure, template_name, :searchable)

      assert search_content == valid_content
    end
  end
end
