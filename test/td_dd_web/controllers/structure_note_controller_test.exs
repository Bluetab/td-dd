defmodule TdDdWeb.StructureNoteControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureNote

  @create_attrs %{
    df_content: %{},
    status: :draft,
    version: 42
  }
  @update_attrs %{
    df_content: %{},
    status: :published,
    version: 43
  }
  @invalid_attrs %{df_content: nil, status: nil, version: nil}

  def fixture(:structure_note) do
    data_structure = insert(:data_structure)
    {:ok, structure_note} = DataStructures.create_structure_note(data_structure, @create_attrs)
    structure_note
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @tag authentication: [role: "admin"]
  describe "index" do
    test "lists all structure_notes", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      conn = get(conn, Routes.data_structure_note_path(conn, :index, data_structure_id))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create structure_note" do
    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      conn =
        post(conn, Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.data_structure_note_path(conn, :show, data_structure_id, id))

      assert %{
               "id" => ^id,
               "df_content" => %{},
               "status" => "draft",
               "version" => 42
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)

      conn =
        post(conn, Routes.data_structure_note_path(conn, :create, data_structure_id),
          structure_note: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update structure_note" do
    setup [:create_structure_note]

    @tag authentication: [role: "admin"]
    test "renders structure_note when data is valid", %{
      conn: conn,
      structure_note:
        %StructureNote{
          id: id,
          data_structure_id: data_structure_id
        } = structure_note
    } do
      conn =
        put(
          conn,
          Routes.data_structure_note_path(conn, :update, data_structure_id, structure_note),
          structure_note: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.data_structure_note_path(conn, :show, data_structure_id, id))

      assert %{
               "id" => ^id,
               "df_content" => %{},
               "status" => "published",
               "version" => 42
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, structure_note: structure_note} do
      conn =
        put(
          conn,
          Routes.data_structure_note_path(
            conn,
            :update,
            structure_note.data_structure.id,
            structure_note
          ),
          structure_note: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete structure_note" do
    setup [:create_structure_note]

    @tag authentication: [role: "admin"]
    test "deletes chosen structure_note", %{conn: conn, structure_note: structure_note} do
      data_structure_id = structure_note.data_structure.id

      conn =
        delete(
          conn,
          Routes.data_structure_note_path(conn, :delete, data_structure_id, structure_note)
        )

      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note))
      end
    end
  end

  defp create_structure_note(_) do
    structure_note = fixture(:structure_note)
    %{structure_note: structure_note}
  end
end
