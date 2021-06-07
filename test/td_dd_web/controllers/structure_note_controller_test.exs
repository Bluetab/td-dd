defmodule TdDdWeb.StructureNoteControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.StructureNote

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @tag authentication: [role: "admin"]
  describe "index" do
    test "lists all structure_notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      assert [] == conn
      |> get(Routes.data_structure_note_path(conn, :index, data_structure_id))
      |> json_response(:ok)
      |> Map.get("data")
    end
  end

  describe "create structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      create_attrs = string_params_for(:structure_note)

      %{"data" => %{"id" => id}} = conn
        |> post(Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: create_attrs
        )
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
    test "renders structure_note when data is valid", %{conn: conn} do
      %StructureNote{
        id: id,
        data_structure_id: data_structure_id
      } = structure_note = insert(:structure_note)

      update_attrs = %{df_content: %{"foo" => "bar"}}

      assert %{"id" => ^id} = conn
        |> put(
          Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
          structure_note: update_attrs
        )
        |> json_response(:ok)
        |> Map.get("data")

      assert %{
        "id" => ^id,
        "df_content" => %{"foo" => "bar"},
        "status" => "draft"
      } = conn
      |> get(Routes.data_structure_note_path(conn, :show, data_structure_id, id))
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
