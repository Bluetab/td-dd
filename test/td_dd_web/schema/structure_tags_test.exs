defmodule TdDdWeb.Schema.StructureTagsTest do
  use TdDdWeb.ConnCase

  @tag_structure """
  mutation TagStructure($structureTag: StructureTagInput!) {
    tagStructure(structureTag: $structureTag) {
      id
      tag {
        id
      }
      dataStructure {
        id
      }
    }
  }
  """

  @delete_structure_tag """
  mutation UntagStructure($id: ID!) {
    deleteStructureTag(id: $id) {
      id
    }
  }
  """

  setup_all do
    :ok
  end

  describe "tagStructure mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a user without permissions", %{conn: conn} do
      %{id: tag_id} = insert(:tag, domain_ids: [123])
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [123])

      variables = %{
        "structureTag" => %{"tagId" => tag_id, "dataStructureId" => data_structure_id}
      }

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tag_structure, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "forbidden", "path" => ["tagStructure"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns forbidden for a user without permissions in domain", %{conn: conn} do
      %{id: tag_id} = insert(:tag, domain_ids: [123])
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [123])

      variables = %{
        "structureTag" => %{"tagId" => tag_id, "dataStructureId" => data_structure_id}
      }

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tag_structure, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "forbidden", "path" => ["tagStructure"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns not_found if structure does not exist", %{conn: conn} do
      %{id: tag_id} = insert(:tag)
      variables = %{"structureTag" => %{"tagId" => tag_id, "dataStructureId" => 123}}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tag_structure, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "not_found", "path" => ["tagStructure"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns not_found if tag does not exist", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      variables = %{"structureTag" => %{"tagId" => 123, "dataStructureId" => data_structure_id}}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tag_structure, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "not_found", "path" => ["tagStructure"]}] = errors
    end

    @tag authentication: [
           role: "user",
           permissions: [:link_data_structure_tag, :view_data_structure]
         ]
    test "returns data on success", %{conn: conn, domain: domain} do
      %{id: tag_id} = insert(:tag, domain_ids: [domain.id])
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      variables = %{
        "structureTag" => %{
          "tagId" => tag_id,
          "dataStructureId" => data_structure_id,
          "comment" => "foo",
          "inherit" => false
        }
      }

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @tag_structure, "variables" => variables})
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"tagStructure" => %{"id" => _, "dataStructure" => %{"id" => _}}} = data
    end
  end

  describe "deleteStructureTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a user without permissions", %{conn: conn} do
      %{id: id} = insert(:structure_tag)
      variables = %{"id" => id}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @delete_structure_tag, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "forbidden", "path" => ["deleteStructureTag"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns not_found if structure tag does not exist", %{conn: conn} do
      variables = %{"id" => 123}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @delete_structure_tag, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "not_found", "path" => ["deleteStructureTag"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns forbidden for user without permission in domain", %{conn: conn} do
      %{id: id} = insert(:structure_tag)

      variables = %{"id" => id}

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @delete_structure_tag, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "forbidden", "path" => ["deleteStructureTag"]}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns data on success", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])
      %{id: id} = insert(:structure_tag, data_structure_id: data_structure_id)

      variables = %{"id" => id}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @delete_structure_tag, "variables" => variables})
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
      assert %{"deleteStructureTag" => %{"id" => _}} = data
    end
  end
end
