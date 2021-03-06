defmodule TdDdWeb.DataStructuresTagsControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)

    on_exit(fn ->
      TaxonomyCache.delete_domain(domain_id)
    end)

    [domain: domain]
  end

  setup tags do
    case tags do
      %{permissions: permissions, claims: %{user_id: user_id}, domain: %{id: domain_id}} ->
        create_acl_entry(user_id, domain_id, permissions)

      _ ->
        :ok
    end

    :ok
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "renderts links of a structure", %{conn: conn, swagger_schema: schema} do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id, name: name} = insert(:data_structure_tag)

      %{id: id, description: description} =
        insert(:data_structures_tags,
          data_structure_tag: tag,
          data_structure: structure
        )

      assert %{
               "data" => [
                 %{
                   "id" => ^id,
                   "description" => ^description,
                   "_embedded" => %{
                     "data_structure" => %{"id" => ^data_structure_id},
                     "data_structure_tag" => %{"id" => ^tag_id, "name" => ^name}
                   }
                 }
               ]
             } =
               conn
               |> get(Routes.data_structure_tags_path(conn, :index, data_structure_id))
               |> validate_resp_schema(schema, "LinksDataStructureTagResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders not found if structure does not exist", %{conn: conn, swagger_schema: schema} do
      data_structure_id = System.unique_integer([:positive])

      assert %{"errors" => %{"detail" => "Not found"}} =
               conn
               |> get(Routes.data_structure_tags_path(conn, :index, data_structure_id))
               |> validate_resp_schema(schema, "LinksDataStructureTagResponse")
               |> json_response(:not_found)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structure]
    test "renders links of a structure when user has permissions", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      structure = %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      tag = %{id: tag_id, name: name} = insert(:data_structure_tag)

      %{id: id, description: description} =
        insert(:data_structures_tags,
          data_structure_tag: tag,
          data_structure: structure
        )

      assert %{
               "data" => [
                 %{
                   "id" => ^id,
                   "description" => ^description,
                   "_embedded" => %{
                     "data_structure" => %{"id" => ^data_structure_id},
                     "data_structure_tag" => %{"id" => ^tag_id, "name" => ^name}
                   }
                 }
               ]
             } =
               conn
               |> get(Routes.data_structure_tags_path(conn, :index, data_structure_id))
               |> validate_resp_schema(schema, "LinksDataStructureTagResponse")
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "renders unauthorized when user has no permissions", %{
      conn: conn,
      domain: domain
    } do
      structure = %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      tag = insert(:data_structure_tag)

      insert(:data_structures_tags,
        data_structure_tag: tag,
        data_structure: structure
      )

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> get(Routes.data_structure_tags_path(conn, :index, data_structure_id))
               |> json_response(403)
    end
  end

  describe "update" do
    @tag authentication: [role: "admin"]
    test "puts link between a tag and its structure", %{conn: conn, swagger_schema: schema} do
      description = "foo"
      %{id: data_structure_id} = insert(:data_structure)
      %{id: tag_id, name: name} = insert(:data_structure_tag)
      tag = %{description: description}

      assert %{
               "data" => %{
                 "description" => ^description,
                 "_embedded" => %{
                   "data_structure" => %{"id" => ^data_structure_id},
                   "data_structure_tag" => %{"id" => ^tag_id, "name" => ^name}
                 }
               }
             } =
               conn
               |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
                 tag: tag
               )
               |> validate_resp_schema(schema, "LinkDataStructureTagResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "updates link between a tag and its structure when it exists", %{
      conn: conn,
      swagger_schema: schema
    } do
      description = "foo"
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id, name: name} = insert(:data_structure_tag)

      insert(:data_structures_tags,
        data_structure_tag: tag,
        data_structure: structure,
        description: "foo"
      )

      tag = %{description: description}

      assert %{
               "data" => %{
                 "description" => ^description,
                 "_embedded" => %{
                   "data_structure" => %{"id" => ^data_structure_id},
                   "data_structure_tag" => %{"id" => ^tag_id, "name" => ^name}
                 }
               }
             } =
               conn
               |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
                 tag: tag
               )
               |> validate_resp_schema(schema, "LinkDataStructureTagResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders not found if structure does not exist", %{conn: conn} do
      description = "foo"
      data_structure_id = System.unique_integer([:positive])
      %{id: tag_id} = insert(:data_structure_tag)
      tag = %{description: description}

      conn
      |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
        tag: tag
      )
      |> response(404)
    end

    @tag authentication: [role: "admin"]
    test "renders not found if tag does not exist", %{conn: conn} do
      description = "foo"
      %{id: data_structure_id} = insert(:data_structure)
      tag_id = System.unique_integer([:positive])
      tag = %{description: description}

      conn
      |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
        tag: tag
      )
      |> response(404)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:link_data_structure_tag]
    test "puts link between a tag and its structure when user has permissions", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      description = "foo"
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      %{id: tag_id, name: name} = insert(:data_structure_tag)
      tag = %{description: description}

      assert %{
               "data" => %{
                 "description" => ^description,
                 "_embedded" => %{
                   "data_structure" => %{"id" => ^data_structure_id},
                   "data_structure_tag" => %{"id" => ^tag_id, "name" => ^name}
                 }
               }
             } =
               conn
               |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
                 tag: tag
               )
               |> validate_resp_schema(schema, "LinkDataStructureTagResponse")
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "renders unauthorized when user has no permissions", %{
      conn: conn,
      domain: domain
    } do
      description = "foo"
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      %{id: tag_id} = insert(:data_structure_tag)
      tag = %{description: description}

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> put(Routes.data_structure_tags_path(conn, :update, data_structure_id, tag_id),
                 tag: tag
               )
               |> json_response(403)
    end
  end

  describe "delete" do
    @tag authentication: [role: "admin"]
    test "deletes link between a tag and its structure", %{conn: conn} do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id} = insert(:data_structure_tag)

      %{id: id} =
        insert(:data_structures_tags,
          data_structure_tag: tag,
          data_structure: structure
        )

      assert %{
               "data" => %{
                 "id" => ^id
               }
             } =
               conn
               |> delete(
                 Routes.data_structure_tags_path(conn, :delete, data_structure_id, tag_id)
               )
               |> json_response(:accepted)
    end

    @tag authentication: [role: "admin"]
    test "renders not found when either structure or tag does not exist", %{
      conn: conn
    } do
      data_structure_id = System.unique_integer([:positive])
      tag_id = System.unique_integer([:positive])

      assert %{"errors" => %{"detail" => "Not found"}} =
               conn
               |> delete(
                 Routes.data_structure_tags_path(conn, :delete, data_structure_id, tag_id)
               )
               |> json_response(:not_found)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:link_data_structure_tag]
    test "deletes link between a tag and its structure when user has permission", %{
      conn: conn,
      domain: domain
    } do
      structure = %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      tag = %{id: tag_id} = insert(:data_structure_tag)

      %{id: id} =
        insert(:data_structures_tags,
          data_structure_tag: tag,
          data_structure: structure
        )

      assert %{
               "data" => %{
                 "id" => ^id
               }
             } =
               conn
               |> delete(
                 Routes.data_structure_tags_path(conn, :delete, data_structure_id, tag_id)
               )
               |> json_response(:accepted)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "gets unauthorized when user has no permissions", %{
      conn: conn,
      domain: domain
    } do
      structure = %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      tag = %{id: tag_id} = insert(:data_structure_tag)

      insert(:data_structures_tags,
        data_structure_tag: tag,
        data_structure: structure
      )

      assert %{
               "errors" => %{"detail" => "Invalid authorization"}
             } =
               conn
               |> delete(
                 Routes.data_structure_tags_path(conn, :delete, data_structure_id, tag_id)
               )
               |> json_response(403)
    end
  end
end
