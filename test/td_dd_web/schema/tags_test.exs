defmodule TdDdWeb.Schema.TagsTest do
  use TdDdWeb.ConnCase

  @tag_query """
  query Tag($id: ID!) {
    tag(id: $id) {
      id
      name
      description
      domainIds
    }
  }
  """

  @tags_query """
  query Tag {
    tags {
      id
      name
      description
      domainIds
      structureCount
    }
  }
  """

  @create_tag """
  mutation CreateTag($tag: TagInput!) {
    createTag(tag: $tag) {
      id
      name
      description
      domainIds
    }
  }
  """

  @update_tag """
  mutation UpdateTag($tag: TagInput!) {
    updateTag(tag: $tag) {
      id
      name
      description
      domainIds
    }
  }
  """

  @delete_tag """
  mutation DeleteTag($id: ID!) {
    deleteTag(id: $id) {
      id
    }
  }
  """

  defp create_tag(%{} = context) do
    %{id: domain_id} = domain = context[:domain] || CacheHelpers.insert_domain()
    [domain: domain, tag: insert(:tag, domain_ids: [domain_id])]
  end

  describe "tag query" do
    setup :create_tag

    @tag authentication: [role: "user", permissions: [:foo]]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @tag_query,
                 "variables" => %{"id" => 123}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{
      conn: conn,
      tag: %{id: tag_id}
    } do
      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @tag_query,
                 "variables" => %{"id" => tag_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"tag" => tag} = data

      assert %{
               "id" => id,
               "domainIds" => [_],
               "name" => _,
               "description" => _
             } = tag

      assert id == to_string(tag_id)
    end
  end

  describe "tags query" do
    setup :create_tag

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @tags_query})
               |> json_response(:ok)

      assert data == %{"tags" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{conn: conn, tag: tag} do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @tags_query})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"tags" => tags} = data

      assert [
               %{
                 "id" => id,
                 "name" => name,
                 "description" => description,
                 "domainIds" => domain_ids
               }
             ] = tags

      assert id == to_string(tag.id)
      assert name == to_string(tag.name)
      assert description == to_string(tag.description)
      assert_lists_equal(domain_ids, tag.domain_ids, &(to_string(&1) == to_string(&2)))
    end
  end

  describe "createTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      params = string_params_for(:tag)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "creates the tag when performed by admin role", %{conn: conn} do
      %{
        "name" => name,
        "description" => description
      } = params = string_params_for(:tag, domain_ids: [123])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @create_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"createTag" => tag} = data

      assert %{
               "id" => _,
               "name" => ^name,
               "description" => ^description,
               "domainIds" => ["123"]
             } = tag
    end

    @tag authentication: [role: "admin"]
    test "Create tag with large description return an error", %{conn: conn} do
      description = String.duplicate("foo", 334)

      %{
        "name" => _name
      } = params = string_params_for(:tag, domain_ids: [123], description: description)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert [%{"field" => "description", "message" => "should be at most 1000 character(s)"}] =
               errors
    end
  end

  describe "updateTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      params = string_params_for(:tag)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns not_found for an admin user", %{conn: conn} do
      params = string_params_for(:tag) |> Map.put("id", 123)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "updates the tag for an admin user", %{conn: conn} do
      %{id: id} = insert(:tag)
      params = string_params_for(:tag) |> Map.put("id", id)

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert %{"updateTag" => %{"id" => _}} = data
    end

    @tag authentication: [role: "admin"]
    test "Update tag with large description return an error", %{conn: conn} do
      %{id: id} = insert(:tag)
      description = String.duplicate("foo", 334)

      params =
        string_params_for(
          :tag,
          domain_ids: [123],
          description: description
        )
        |> Map.put("id", id)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_tag,
                 "variables" => %{"tag" => params}
               })
               |> json_response(:ok)

      assert [%{"field" => "description", "message" => "should be at most 1000 character(s)"}] =
               errors
    end
  end

  describe "deleteTag mutation" do
    @tag authentication: [role: "user"]
    test "returns forbidden for a non-admin user", %{conn: conn} do
      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_tag,
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
                 "query" => @delete_tag,
                 "variables" => %{"id" => "123"}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "deletes the tag for an admin user", %{conn: conn} do
      %{id: id} = insert(:tag)

      assert %{"data" => data} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_tag,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert %{"deleteTag" => %{"id" => _}} = data
    end
  end
end
