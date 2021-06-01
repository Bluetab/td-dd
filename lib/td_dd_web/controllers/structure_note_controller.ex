defmodule TdDdWeb.StructureNoteController do
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotesWorkflow

  action_fallback TdDdWeb.FallbackController

  def index(conn, %{
        "data_structure_id" => _data_structure_id
      }) do
    structure_notes = DataStructures.list_structure_notes()
    render(conn, "index.json", structure_notes: structure_notes)
  end

  def create(conn, %{
        "data_structure_id" => data_structure_id,
        "structure_note" => structure_note_params
      }) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, create(StructureNote))},
         data_structure <- DataStructures.get_data_structure!(data_structure_id),
         {:ok, %StructureNote{} = structure_note} <-
           StructureNotesWorkflow.create(data_structure, structure_note_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note)
      )
      |> render("show.json", structure_note: structure_note)
    end
  end

  def show(conn, %{"id" => id}) do
    structure_note = DataStructures.get_structure_note!(id)
    render(conn, "show.json", structure_note: structure_note)
  end

  def update(conn, %{"id" => id, "structure_note" => structure_note_params}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, publish_from_draft(StructureNote))},
         structure_note = DataStructures.get_structure_note!(id),
         {:ok, %StructureNote{} = structure_note} <-
           DataStructures.update_structure_note(structure_note, structure_note_params) do
      render(conn, "show.json", structure_note: structure_note)
    end
  end

  def delete(conn, %{"id" => id}) do
    structure_note = DataStructures.get_structure_note!(id)

    with {:ok, %StructureNote{}} <- DataStructures.delete_structure_note(structure_note) do
      send_resp(conn, :no_content, "")
    end
  end
end
