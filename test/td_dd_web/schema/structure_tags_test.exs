defmodule TdDdWeb.Schema.StructureTagsTest do
  use TdDdWeb.ConnCase

  @structure_tag """
  query StructureTag($id: ID!) {
    structureTag(id: $id) {
      id
      name
      description
      domainIds
    }
  }
  """

  @structure_tags """
  query StructureTags {
    structureTags {
      id
      name
      description
      domainIds
      structureCount
    }
  }
  """

  @create_structure_tag """
  mutation CreateStructureTag($structureTag: StructureTagInput!) {
    createStructureTag(structureTag: $structureTag) {
      id
      name
      description
      domainIds
    }
  }
  """

  @update_structure_tag """
  mutation UpdateStructureTag($structureTag: StructureTagInput!) {
    updateStructureTag(structureTag: $structureTag) {
      id
      name
      description
      domainIds
    }
  }
  """

  @delete_structure_tag """
  mutation DeleteStructureTag($id: ID!) {
    deleteStructureTag(id: $id) {
      id
    }
  }
  """

  defp create_structure_tag(%{} = context) do
    %{id: domain_id} = domain = context[:domain] || CacheHelpers.insert_domain()
    [domain: domain, structure_tag: insert(:data_structure_tag, domain_ids: [domain_id])]
  end

  describe "structureTag query" do
    setup :create_structure_tag

    @tag authentication: [role: "user", permissions: [:foo]]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @structure_tag,
                 "variables" => %{"id" => 123}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{
      conn: conn,
      structure_tag: %{id: structure_tag_id}
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @structure_tag,
                 "variables" => %{"id" => structure_tag_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"structureTag" => structure_tag} = data

      assert %{
               "id" => id,
               "domainIds" => [_],
               "name" => _,
               "description" => _
             } = structure_tag

      assert id == to_string(structure_tag_id)
    end
  end

  describe "structureTags query" do
    setup :create_structure_tag

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_tags})
               |> json_response(:ok)

      assert data == %{"structureTags" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{conn: conn, structure_tag: structure_tag} do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @structure_tags})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"structureTags" => structure_tags} = data

      assert [
               %{
                 "id" => id,
                 "name" => name,
                 "description" => description,
                 "domainIds" => domain_ids
               }
             ] = structure_tags

      assert id == to_string(structure_tag.id)
      assert name == to_string(structure_tag.name)
      assert description == to_string(structure_tag.description)
      assert_lists_equal(domain_ids, structure_tag.domain_ids, &(to_string(&1) == to_string(&2)))
    end
  end

  describe "createStructureTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      params = string_params_for(:data_structure_tag)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "creates the structure tag when performed by admin role", %{conn: conn} do
      %{
        "name" => name,
        "description" => description
      } = params = string_params_for(:data_structure_tag, domain_ids: [123])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @create_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"createStructureTag" => structure_tag} = data

      assert %{
               "id" => _,
               "name" => ^name,
               "description" => ^description,
               "domainIds" => ["123"]
             } = structure_tag
    end

    @tag authentication: [role: "admin"]
    test "Create structure tag with large description return an error", %{conn: conn} do
      description = String.duplicate("foo", 334)

      %{
        "name" => _name
      } =
        params =
        string_params_for(:data_structure_tag, domain_ids: [123], description: description)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "max.length.1000"}] = errors
    end
  end

  describe "updateStructureTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      params = string_params_for(:data_structure_tag)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      params = string_params_for(:data_structure_tag) |> Map.put("id", 123)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "updates the structure tag for an admin user", %{conn: conn} do
      %{id: id} = insert(:data_structure_tag)
      params = string_params_for(:data_structure_tag) |> Map.put("id", id)

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert %{"updateStructureTag" => %{"id" => _}} = data
    end

    @tag authentication: [role: "admin"]
    test "Update structure tag with large description return an error", %{conn: conn} do
      %{id: id} = insert(:data_structure_tag)
      description = String.duplicate("foo", 334)

      params =
        string_params_for(
          :data_structure_tag,
          domain_ids: [123],
          description: description
        )
        |> Map.put("id", id)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_structure_tag,
                 "variables" => %{"structureTag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "max.length.1000"}] = errors
    end
  end

  describe "deleteStructureTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_structure_tag,
                 "variables" => %{"id" => "123"}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_structure_tag,
                 "variables" => %{"id" => "123"}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "deletes the structure tag for an admin user", %{conn: conn} do
      %{id: id} = insert(:data_structure_tag)

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_structure_tag,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert %{"deleteStructureTag" => %{"id" => _}} = data
    end
  end
end
