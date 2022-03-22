defmodule TdDdWeb.Schema.StructuresTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes

  @moduletag sandbox: :shared

  @query """
  query DataStructureVersions($since: DateTime) {
    dataStructureVersions(since: $since) {
      id
      metadata
      name
      dataStructure {
        id
        externalId
        domainId
        domainIds
        system {
          id
          externalId
        }
      }
    }
  }
  """

  @path_query """
  query DataStructureVersions {
    dataStructureVersions {
      id
      name
      path
    }
  }
  """
  @variables %{"since" => "2020-01-01T00:00:00Z"}
  @metadata %{"foo" => ["bar"]}

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "dataStructureVersions query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert data == %{"dataStructureVersions" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "service"]
    test "returns data when queried by service role", %{conn: conn} do
      insert(:data_structure_version,
        updated_at: ~U[2019-01-01T00:00:00Z],
        deleted_at: ~U[2019-01-01T00:00:00Z]
      )

      %{id: expected_id, name: name} =
        insert(:data_structure_version, metadata: @metadata, domain_ids: [1, 2])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      assert [
               %{
                 "id" => id,
                 "dataStructure" => data_structure,
                 "metadata" => @metadata,
                 "name" => ^name
               }
             ] = data_structure_versions

      assert id == to_string(expected_id)

      assert %{
               "id" => _,
               "externalId" => _,
               "system" => system,
               "domainId" => 1,
               "domainIds" => [1, 2]
             } = data_structure

      assert %{"id" => _, "externalId" => _} = system
    end

    @tag authentication: [role: "service"]
    test "returns correct path for structure version", %{conn: conn} do
      domain_id = System.unique_integer([:positive])
      %{id: system_id} = insert(:system)

      %{id: child_id} =
        insert(:data_structure_version,
          name: "child",
          data_structure:
            build(:data_structure,
              external_id: "child",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      %{id: default_parent_id} =
        insert(:data_structure_version,
          name: "default_parent",
          data_structure:
            build(:data_structure,
              external_id: "default_parent",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      %{id: other_parent_id} =
        insert(:data_structure_version,
          name: "other_parent",
          data_structure:
            build(:data_structure,
              external_id: "other_parent",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      default_relation_id = RelationTypes.default_id!()
      %{id: custom_relation_id} = insert(:relation_type, name: "relation_type_1")

      insert(:data_structure_relation,
        parent_id: default_parent_id,
        child_id: child_id,
        relation_type_id: default_relation_id
      )

      insert(:data_structure_relation,
        parent_id: other_parent_id,
        child_id: child_id,
        relation_type_id: custom_relation_id
      )

      Hierarchy.update_hierarchy([child_id])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @path_query})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      assert [
               %{
                 "id" => id,
                 "name" => "child",
                 "path" => ["default_parent"]
               },
               %{"name" => "default_parent"},
               %{"name" => "other_parent"}
             ] = data_structure_versions

      assert id == to_string(child_id)
    end
  end
end
