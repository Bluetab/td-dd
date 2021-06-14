defmodule TdDdWeb.StructureNoteControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.StructureNote

  import TdDd.TestOperators

  @moduletag sandbox: :shared
  @template_name "structure_note_controller_test_template"

  setup %{conn: conn} do
    %{id: template_id, name: template_name} = template = build(:template, name: @template_name)
    {:ok, _} = TemplateCache.put(template, publish: false)
    CacheHelpers.insert_structure_type(structure_type: template_name, template_id: template_id)
    on_exit(fn -> TemplateCache.delete(template_id) end)

    start_supervised!(TdDd.Search.StructureEnricher)
    {:ok, %{conn: put_req_header(conn, "accept", "application/json")}}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all structure_notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      assert [] == conn
      |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
      |> json_response(:ok)
      |> Map.get("data")
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:view_structure_note_history]
    ]
    test "lists all structure_notes if user has the view_structure_note_history permission", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      assert [] == conn
      |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
      |> json_response(:ok)
      |> Map.get("data")
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:some_permission]
    ]
    test "can't lists all structure_notes if user hasn't the correct permission", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      conn
      |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
      |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "only list structure notes of its data structure", %{conn: conn, swagger_schema: schema} do
      %{id: first_data_structure_id} = first_data_structure = insert(:data_structure)
      %{id: second_data_structure_id} = second_data_structure = insert(:data_structure)

      first_structure_notes = [
        insert(:structure_note, data_structure: first_data_structure, status: :rejected, version: 1),
        insert(:structure_note, data_structure: first_data_structure, status: :published, version: 2),
        insert(:structure_note, data_structure: first_data_structure, status: :draft, version: 3)
      ]
      |> Enum.map(fn(sn) -> sn.id end)

      second_structure_notes = [
        insert(:structure_note, data_structure: second_data_structure, status: :draft, version: 2),
        insert(:structure_note, data_structure: second_data_structure, status: :rejected, version: 1)
      ]
      |> Enum.map(fn(sn) -> sn.id end)

      assert first_structure_notes <|> (conn
      |> get(Routes.data_structure_note_path(conn, :index, first_data_structure_id))
      |> validate_resp_schema(schema, "StructureNotesResponse")
      |> json_response(:ok)
      |> Map.get("data")
      |> Enum.map(fn(sn) -> Map.get(sn, "id") end))

      assert second_structure_notes <|> (conn
      |> get(Routes.data_structure_note_path(conn, :index, second_data_structure_id))
      |> json_response(:ok)
      |> Map.get("data")
      |> Enum.map(fn(sn) -> Map.get(sn, "id") end))
    end
  end

  describe "create structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn, swagger_schema: schema} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> validate_resp_schema(schema, "StructureNoteResponse")
        |> json_response(:created)

      assert %{
               "id" => ^id,
               "df_content" => %{},
               "status" => "draft",
               "version" => 1
             } =
              conn
              |> get(Routes.data_structure_note_path(conn, :show, data_structure_id, id))
              |> json_response(:ok)
              |> Map.get("data")
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot create structure_note", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      assert conn
               |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
                 structure_note: create_attrs
               )
               |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders error when creating note with existing draft", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)
      assert conn
       |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
           structure_note: create_attrs
         )
        |> json_response(:conflict)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      assert %{"df_content" => ["can't be blank"]} =
               conn
               |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
                 structure_note: %{}
               )
               |> json_response(:unprocessable_entity)
               |> Map.get("errors")

    end
  end

  describe "update structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn, swagger_schema: schema} do
      data_structure = insert(:data_structure)
      %StructureNote{id: id} = structure_note = insert(:structure_note, data_structure: data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: @template_name
      )

      update_attrs = %{df_content: %{"string" => "value", "list" => "two"}}

      assert %{"id" => ^id} = conn
        |> put(
          Routes.data_structure_note_path(conn, :update, data_structure.id, structure_note),
          structure_note: update_attrs
        )
        |> validate_resp_schema(schema, "StructureNoteResponse")
        |> json_response(:ok)
        |> Map.get("data")

      assert %{
        "id" => ^id,
        "df_content" => %{"string" => "value", "list" => "two"},
        "status" => "draft"
      } = conn
      |> get(Routes.data_structure_note_path(conn, :show, data_structure.id, id))
      |> json_response(:ok)
      |> Map.get("data")
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      structure_note = insert(:structure_note)

      assert %{"errors" => errors} = conn
        |> put(
          Routes.data_structure_note_path(
            conn,
            :update,
            structure_note.data_structure.id,
            structure_note
          ),
          structure_note: %{df_content: nil}
        )
        |> json_response(:unprocessable_entity)

      assert %{
        "df_content" => ["can't be blank"]
      } = errors
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user can not publish a draft note", %{conn: conn} do
      %StructureNote{
        data_structure_id: data_structure_id
      } = structure_note = insert(:structure_note)

      update_attrs =
        string_params_for(:structure_note, status: "published", df_content: %{"foo" => "bar"})

      conn
        |> put(
          Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
          structure_note: update_attrs
        )
        |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "can publish a draft note when the user has the right permissions", %{conn: conn} do
      %StructureNote{
        data_structure_id: data_structure_id
      } = structure_note = insert(:structure_note)

      update_attrs = %{"status" => "published"}

      conn
        |> put(
          Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
          structure_note: update_attrs
        )
        |> json_response(:ok)
    end
  end

  describe "delete structure_note" do
    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:delete_structure_note]
    ]
    test "deletes chosen structure_note", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      structure_note = insert(:structure_note, data_structure_id: data_structure_id)

      assert conn
        |> delete(Routes.data_structure_note_path(conn, :delete, data_structure_id, structure_note))
        |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note))
      end
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note]
    ]
    test "cannot delete structure_note without permission", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      structure_note = insert(:structure_note, data_structure_id: data_structure_id)

      assert conn
        |> delete(Routes.data_structure_note_path(conn, :delete, data_structure_id, structure_note))
        |> response(:forbidden)
    end
  end

  describe "permissions over structure_notes" do

    @tag authentication: [user_name: "non_admin_user"]
    test "can't create notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:forbidden)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note]
    ]
    test "can create notes", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:view_structure_note]
    ]
    test "can not create notes", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:forbidden)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note, :edit_structure_note]
    ]
    test "can edit note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      body = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "edited" in (body |> Map.get("_actions") |> Map.keys)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note]
    ]
    test "can not edit or publish note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      body = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "edited" not in (body |> Map.get("_actions") |> Map.keys)
      assert "published" not in (body |> Map.get("_actions") |> Map.keys)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note, :publish_structure_note_from_draft]
    ]
    test "can not publish note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      body = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "published" in (body |> Map.get("_actions") |> Map.keys)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note, :reject_structure_note, :send_structure_note_to_approval]
    ]
    test "can reject a note after send to approval but not after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} = creation_body = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      pending_approval_body = conn
        |> put(Routes.data_structure_note_path(conn, :update, data_structure_id, id),
          structure_note: %{"status" => "pending_approval"}
        )
        |> json_response(:ok)

      assert "rejected" not in (creation_body |> Map.get("_actions") |> Map.keys)
      assert "rejected" in (pending_approval_body |> Map.get("_actions") |> Map.keys)
    end

    @tag authentication: [
      user_name: "non_admin_user",
      permissions: [:create_structure_note, :publish_structure_note_from_draft]
    ]
    test "cannot delete a note after creation", %{conn: conn, domain: domain} do
      %{id: data_structure_id} = insert(:data_structure, domain_id: domain.id)
      create_attrs = string_params_for(:structure_note)

      body = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
        |> json_response(:created)

      assert "deleted" not in (body |> Map.get("_actions") |> Map.keys)
    end
  end
end
