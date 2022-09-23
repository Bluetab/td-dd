defmodule TdDdWeb.StructureNoteController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Bodyguard, only: [permit?: 4]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.StructureNotesWorkflow
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)
  @data_structure_type_preload [:system, [current_version: :structure_type]]

  def swagger_definitions do
    SwaggerDefinitions.structure_note_swagger_definitions()
  end

  swagger_path :index do
    description("List StructureNotes of a DataStructure")
    produces("application/json")

    parameters do
      data_structure_id(:path, :string, "Data Structure Id", required: true)
    end

    response(200, "OK", Schema.ref(:StructureNotesResponse))
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def index(conn, %{"data_structure_id" => data_structure_id}) do
    with claims <- conn.assigns[:current_resource],
         data_structure <- DataStructures.get_data_structure!(data_structure_id),
         :ok <- Bodyguard.permit(DataStructures, :view_data_structure, claims, data_structure),
         statuses <- listable_statuses(claims, data_structure) do
      structure_notes =
        data_structure_id
        |> StructureNotes.list_structure_notes(statuses)
        |> Enum.map(fn sn ->
          Map.put(sn, :actions, available_actions(conn, sn, claims, data_structure))
        end)

      render(conn, "index.json",
        structure_notes: structure_notes,
        actions: available_actions(conn, nil, claims, data_structure)
      )
    end
  end

  def search(conn, filter) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(StructureNotes, :search, claims) do
      structure_notes = StructureNotes.list_structure_notes(filter)

      render(conn, "search.json", structure_notes: structure_notes)
    end
  end

  swagger_path :create do
    description("Creates Structure Note")
    produces("application/json")

    parameters do
      data_structure_id(:path, :string, "Data Structure Id", required: true)

      structure_note(
        :body,
        Schema.ref(:CreateStructureNote),
        "StructureNote create attrs"
      )
    end

    response(201, "OK", Schema.ref(:StructureNoteResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(
        conn,
        %{
          "data_structure_id" => data_structure_id,
          "structure_note" => _structure_note_params,
          "force" => true
        } = params
      ) do
    with claims <- conn.assigns[:current_resource],
         data_structure <- DataStructures.get_data_structure!(data_structure_id),
         :ok <-
           Bodyguard.permit(StructureNotes, :force_create_structure_note, claims, data_structure) do
      create(conn, params, true)
    end
  end

  def create(
        conn,
        %{
          "data_structure_id" => _data_structure_id,
          "structure_note" => _structure_note_params
        } = params
      ) do
    create(conn, params, false)
  end

  defp create(
         conn,
         %{
           "data_structure_id" => data_structure_id,
           "structure_note" => structure_note_params
         },
         force_creation
       ) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         data_structure <-
           DataStructures.get_data_structure!(data_structure_id, @data_structure_type_preload),
         :ok <- Bodyguard.permit(StructureNotes, :create_structure_note, claims, data_structure),
         {:ok, %StructureNote{} = structure_note} <-
           StructureNotesWorkflow.create(
             data_structure,
             structure_note_params,
             force_creation,
             user_id
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note)
      )
      |> render("show.json",
        structure_note: structure_note,
        actions: available_actions(conn, structure_note, claims, data_structure)
      )
    end
  end

  def create_by_external_id(
        conn,
        %{"structure_note" => %{"data_structure_external_id" => external_id}} = params
      ) do
    with claims <- conn.assigns[:current_resource],
         data_structure <- DataStructures.get_data_structure_by_external_id(external_id),
         :ok <- Bodyguard.permit(StructureNotes, :force_create_structure_note, claims, data_structure) do
      creation_params = Map.put(params, "data_structure_id", data_structure.id)
      create(conn, creation_params, true)
    end
  end

  swagger_path :show do
    description("Shows Structure Note")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
      id(:path, :string, "Structure Note Id", required: true)
    end

    response(200, "OK", Schema.ref(:StructureNoteResponse))
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    structure_note = StructureNotes.get_structure_note!(id)
    render(conn, "show.json", structure_note: structure_note)
  end

  swagger_path :update do
    description("Updates Structure Note")
    produces("application/json")

    parameters do
      data_structure_id(:path, :string, "Data Structure Id", required: true)
      id(:path, :string, "Structure Note Id", required: true)

      structure_note(
        :body,
        Schema.ref(:UpdateStructureNote),
        "StructureNote update attrs"
      )
    end

    response(201, "OK", Schema.ref(:StructureNoteResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{
        "data_structure_id" => data_structure_id,
        "id" => id,
        "structure_note" => structure_note_params
      }) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         data_structure <-
           DataStructures.get_data_structure!(data_structure_id, @data_structure_type_preload),
         structure_note = StructureNotes.get_structure_note!(id),
         {:can, true} <- can(structure_note, structure_note_params, claims, data_structure),
         {:ok, %StructureNote{} = structure_note} <-
           StructureNotesWorkflow.update(
             structure_note,
             structure_note_params,
             true,
             user_id,
             DataStructures.get_data_structure_type(data_structure)
           ) do
      conn
      |> put_resp_header(
        "location",
        Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note)
      )
      |> render("show.json",
        structure_note: structure_note,
        actions: available_actions(conn, structure_note, claims, data_structure)
      )
    end
  end

  swagger_path :delete do
    description("Deletes Structure Note")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
      id(:path, :integer, "Data Structure Note ID", required: true)
    end

    response(202, "Accepted")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    structure_note = StructureNotes.get_structure_note!(id)

    with claims <- conn.assigns[:current_resource],
         data_structure <- DataStructures.get_data_structure!(structure_note.data_structure_id),
         :ok <- Bodyguard.permit(StructureNotes, :delete_structure_note, claims, data_structure),
         {:ok, %StructureNote{}} <- StructureNotesWorkflow.delete(structure_note, claims.user_id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp can(%{status: _status}, %{"status" => nil}, _claims, _data_structure), do: {:can, true}

  defp can(%{status: status}, %{"status" => to_status}, claims, data_structure) do
    {:can, is_available(status, String.to_atom(to_status), claims, data_structure)}
  end

  defp can(%{status: :draft}, %{"df_content" => _df_content}, claims, data_structure) do
    {:can, permit?(StructureNotes, :edit_structure_note, claims, data_structure)}
  end

  defp available_actions(conn, nil = structure_note, claims, data_structure) do
    structure_note
    |> available_statutes(claims, data_structure)
    |> Enum.reduce(%{}, fn action, acc ->
      Map.put(acc, action, get_action_location(conn, action, data_structure.id, structure_note))
    end)
  end

  defp available_actions(conn, structure_note, claims, data_structure) do
    structure_note
    |> available_statutes(claims, data_structure)
    |> Enum.reduce(%{}, fn action, acc ->
      Map.put(acc, action, get_action_location(conn, action, data_structure.id, structure_note))
    end)
  end

  defp get_action_location(conn, :draft, data_structure_id, %{status: :rejected} = structure_note) do
    %{
      id: structure_note.id,
      href: Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note),
      input: %{status: :draft},
      method: "PATCH"
    }
  end

  defp get_action_location(conn, :draft, data_structure_id, _) do
    %{
      href: Routes.data_structure_note_path(conn, :create, data_structure_id),
      input: %{df_content: %{}},
      method: "POST"
    }
  end

  defp get_action_location(conn, :edited, data_structure_id, structure_note) do
    %{
      id: structure_note.id,
      href: Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note),
      input: %{df_content: %{}},
      method: "PATCH"
    }
  end

  defp get_action_location(conn, :deleted, data_structure_id, structure_note) do
    %{
      id: structure_note.id,
      href: Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note),
      input: %{},
      method: "DELETE"
    }
  end

  defp get_action_location(conn, action, data_structure_id, structure_note) do
    %{
      id: structure_note.id,
      href: Routes.data_structure_note_path(conn, :show, data_structure_id, structure_note),
      input: %{status: action},
      method: "PATCH"
    }
  end

  defp available_statutes(nil, claims, data_structure) do
    data_structure
    |> StructureNotesWorkflow.available_actions()
    |> Enum.filter(fn action ->
      is_available(nil, action, claims, data_structure)
    end)
  end

  defp available_statutes(%{status: status} = structure_note, claims, data_structure) do
    structure_note
    |> StructureNotesWorkflow.available_actions()
    |> Enum.filter(fn action ->
      is_available(status, action, claims, data_structure)
    end)
  end

  defp is_available(:draft, :published, claims, data_structure),
    do: permit?(StructureNotes, :publish_structure_note_from_draft, claims, data_structure)

  defp is_available(nil, :draft, claims, data_structure),
    do: permit?(StructureNotes, :edit_structure_note, claims, data_structure)

  defp is_available(:draft, :edited, claims, data_structure),
    do: permit?(StructureNotes, :edit_structure_note, claims, data_structure)

  defp is_available(_, :pending_approval, claims, data_structure),
    do: permit?(StructureNotes, :send_structure_note_to_approval, claims, data_structure)

  defp is_available(_, :rejected, claims, data_structure),
    do: permit?(StructureNotes, :reject_structure_note, claims, data_structure)

  defp is_available(:rejected, :draft, claims, data_structure),
    do: permit?(StructureNotes, :unreject_structure_note, claims, data_structure)

  defp is_available(_, :draft, claims, data_structure),
    do: permit?(StructureNotes, :unreject_structure_note, claims, data_structure)

  defp is_available(_, :deprecated, claims, data_structure),
    do: permit?(StructureNotes, :deprecate_structure_note, claims, data_structure)

  defp is_available(_, :published, claims, data_structure),
    do: permit?(StructureNotes, :publish_structure_note, claims, data_structure)

  defp is_available(_, :deleted, claims, data_structure),
    do: permit?(StructureNotes, :delete_structure_note, claims, data_structure)

  defp is_available(_, _, _claims, _data_structure), do: false

  defp listable_statuses(claims, data_structure) do
    [
      {permit?(StructureNotes, :edit_structure_note, claims, data_structure), [:draft]},
      {permit?(StructureNotes, :send_structure_note_to_approval, claims, data_structure),
       [:draft, :pending_approval]},
      {permit?(StructureNotes, :reject_structure_note, claims, data_structure),
       [:pending_approval, :rejected]},
      {permit?(StructureNotes, :unreject_structure_note, claims, data_structure),
       [:rejected, :draft]},
      {permit?(StructureNotes, :deprecate_structure_note, claims, data_structure), [:deprecated]},
      {permit?(StructureNotes, :publish_structure_note, claims, data_structure),
       [:pending_approval]},
      {permit?(StructureNotes, :delete_structure_note, claims, data_structure),
       [:draft, :rejected]},
      {permit?(StructureNotes, :publish_structure_note_from_draft, claims, data_structure),
       [:draft]},
      {permit?(StructureNotes, :view_structure_note_history, claims, data_structure),
       [:versioned, :deprecated]},
      {permit?(DataStructures, :view_data_structure, claims, data_structure), [:published]}
    ]
    |> Enum.filter(fn {permission, _} -> permission end)
    |> Enum.flat_map(fn {_, statuses} -> statuses end)
    |> Enum.uniq()
  end
end
