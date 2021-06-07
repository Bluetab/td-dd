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
         %{domain_id: domain_id} = data_structure <- DataStructures.get_data_structure!(data_structure_id),
         {:can, true} <- {:can, can?(claims, create_structure_note({StructureNote, domain_id}))},
         {:ok, %StructureNote{} = structure_note} <-
           StructureNotesWorkflow.create(data_structure, structure_note_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note)
      )
      |> render("show.json", structure_note: structure_note, actions: available_actions(structure_note, claims, domain_id))
    end
  end

  def show(conn, %{"id" => id}) do
    structure_note = DataStructures.get_structure_note!(id)
    render(conn, "show.json", structure_note: structure_note)
  end

  def update(conn, %{
    "data_structure_id" => data_structure_id,
    "id" => id,
    "structure_note" => structure_note_params}) do
    with claims <- conn.assigns[:current_resource],
         %{domain_id: domain_id} <- DataStructures.get_data_structure!(data_structure_id),
         structure_note = DataStructures.get_structure_note!(id),
         {:can, true} <- can(structure_note, structure_note_params, claims, domain_id),
         {:ok, %StructureNote{} = structure_note} <-
          StructureNotesWorkflow.update(structure_note, structure_note_params) do

      conn
      |> put_resp_header(
        "location",
        Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note)
      )
      |> render("show.json", structure_note: structure_note, actions: available_actions(structure_note, claims, domain_id))
    end
  end

  def delete(conn, %{"id" => id}) do
    structure_note = DataStructures.get_structure_note!(id)

    with claims <- conn.assigns[:current_resource],
         %{domain_id: domain_id} <- DataStructures.get_data_structure!(structure_note.data_structure_id),
         {:can, true} <- {:can, can?(claims, delete_structure_note({StructureNote, domain_id}))},
         {:ok, %StructureNote{}} <- StructureNotesWorkflow.delete(structure_note) do
      send_resp(conn, :no_content, "")
    end
  end

  defp can(%{status: _status}, %{"status" => nil}, _claims, _domain_id), do: {:can, true}
  defp can(%{status: status}, %{"status" => to_status}, claims, domain_id) do
    {:can, is_available(status, String.to_atom(to_status), claims, domain_id)}
  end

  defp can(%{status: :draft}, %{"df_content" => _df_content}, claims, domain_id) do
    {:can, can?(claims, edit_structure_note({StructureNote, domain_id}))}
  end

  defp available_actions(%{status: status} = structure_note, claims, domain_id) do
    structure_note
    |> StructureNotesWorkflow.available_actions
    |> Enum.filter(fn(action) ->
      is_available(status, action, claims, domain_id)
    end)
  end

  defp is_available(:draft, :published, claims, domain_id) do
    can?(claims, publish_structure_note_from_draft({StructureNote, domain_id}))
  end
  defp is_available(status, action, claims, domain_id) do
    case {status, action} do
      {:draft, :edited} -> can?(claims, edit_structure_note({StructureNote, domain_id}))
      {_, :pending_approval} -> can?(claims, send_structure_note_to_approval({StructureNote, domain_id}))
      {_, :rejected} -> can?(claims, reject_structure_note({StructureNote, domain_id}))
      {_, :draft} -> can?(claims, unreject_structure_note({StructureNote, domain_id}))
      {_, :deprecated} -> can?(claims, deprecate_structure_note({StructureNote, domain_id}))
      {_, :published} -> can?(claims, publish_structure_note({StructureNote, domain_id}))
      {_, :deleted} -> can?(claims, delete_structure_note({StructureNote, domain_id}))
      {_, _} -> true
    end
  end
end
