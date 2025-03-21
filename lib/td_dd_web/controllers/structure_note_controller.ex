defmodule TdDdWeb.StructureNoteController do
  use TdDdWeb, :controller

  import Bodyguard, only: [permit?: 4]

  alias TdCluster.Cluster.TdAi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.StructureNotesWorkflow

  alias TdDfLib.MapDiff

  action_fallback(TdDdWeb.FallbackController)
  @data_structure_type_preload [:system, [current_version: :structure_type]]

  def index(conn, %{"data_structure_id" => data_structure_id}) do
    with claims <- conn.assigns[:current_resource],
         data_structure <-
           DataStructures.get_data_structure!(data_structure_id, [
             :system,
             current_version: :structure_type
           ]),
         :ok <- Bodyguard.permit(DataStructures, :view_data_structure, claims, data_structure),
         statuses <- listable_statuses(claims, data_structure) do
      allowed_structure_notes = StructureNotes.list_structure_notes(data_structure_id, statuses)

      structure_notes =
        allowed_structure_notes
        |> Enum.map(fn sn ->
          sn
          |> Map.put(:actions, available_actions(conn, sn, claims, data_structure))
          |> maybe_add_structure_note_diff(allowed_structure_notes)
          |> add_template_id(data_structure)
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
         :ok <- Bodyguard.permit(StructureNotes, :create, claims, data_structure),
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
         :ok <-
           Bodyguard.permit(StructureNotes, :force_create_structure_note, claims, data_structure) do
      creation_params = Map.put(params, "data_structure_id", data_structure.id)
      create(conn, creation_params, true)
    end
  end

  def show(conn, %{"id" => id}) do
    structure_note = StructureNotes.get_structure_note!(id)
    render(conn, "show.json", structure_note: structure_note)
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

  def delete(conn, %{"id" => id}) do
    structure_note = StructureNotes.get_structure_note!(id)

    with claims <- conn.assigns[:current_resource],
         data_structure <- DataStructures.get_data_structure!(structure_note.data_structure_id),
         :ok <- Bodyguard.permit(StructureNotes, :delete, claims, data_structure),
         {:ok, %StructureNote{}} <- StructureNotesWorkflow.delete(structure_note, claims.user_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def note_suggestions(conn, %{"data_structure_id" => data_structure_id} = params) do
    language = Map.get(params, "language", "en")

    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         %{
           current_version: %{structure_type: %{template_id: template_id}, type: structure_type},
           system: %{external_id: system_external_id}
         } = data_structure <-
           DataStructures.get_data_structure!(
             data_structure_id,
             [:system, current_version: [:structure_type]]
           ),
         :ok <- Bodyguard.permit(StructureNotes, :ai_suggestions, claims, data_structure) do
      fields = StructureNotes.suggestion_fields_for_template(template_id)

      TdAi.resource_field_completion(
        "data_structure",
        data_structure_id,
        fields,
        language: language,
        requested_by: user_id,
        selector: %{
          "type" => structure_type,
          "system_external_id" => system_external_id
        }
      )
      |> case do
        {:ok, suggestions} -> render(conn, "suggestions.json", suggestions: suggestions)
        {:error, error} -> {:error, :unprocessable_entity, error}
      end
    end
  end

  defp can(%{status: _status}, %{"status" => nil}, _claims, _data_structure), do: {:can, true}

  defp can(%{status: status}, %{"status" => to_status}, claims, data_structure) do
    {:can, available?(status, String.to_atom(to_status), claims, data_structure)}
  end

  defp can(%{status: :draft}, %{"df_content" => _df_content}, claims, data_structure) do
    {:can, permit?(StructureNotes, :edit, claims, data_structure)}
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

  defp get_action_location(conn, :ai_suggestions, data_structure_id, _) do
    %{
      href: Routes.data_structure_structure_note_path(conn, :note_suggestions, data_structure_id),
      method: "GET"
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
      available?(nil, action, claims, data_structure)
    end)
  end

  defp available_statutes(%{status: status} = structure_note, claims, data_structure) do
    structure_note
    |> StructureNotesWorkflow.available_actions()
    |> Enum.filter(fn action ->
      available?(status, action, claims, data_structure)
    end)
  end

  defp maybe_add_structure_note_diff(
         %{status: status} = draft_structure_note,
         allowed_structure_notes
       )
       when status in [:draft, :pending_approval] do
    published_structure_note =
      allowed_structure_notes
      |> Enum.find(%TdDd.DataStructures.StructureNote{}, fn asn ->
        asn.status == :published
      end)
      |> Map.from_struct()
      |> Map.get(:df_content, %{})

    diff =
      draft_structure_note
      |> Map.from_struct()
      |> Map.get(:df_content)
      |> MapDiff.diff(published_structure_note)
      |> Map.values()
      |> Enum.map(&Map.keys(&1))
      |> List.flatten()

    Map.put(draft_structure_note, :_diff, diff)
  end

  defp maybe_add_structure_note_diff(structure_note, _allowed_structure_notes), do: structure_note

  defp add_template_id(
         structure_note,
         %{current_version: %{structure_type: %{template_id: template_id}}}
       ) do
    Map.put(structure_note, :template_id, template_id)
  end

  defp add_template_id(structure_note, _), do: structure_note

  defp available?(:draft, :published, claims, data_structure),
    do: permit?(StructureNotes, :publish_draft, claims, data_structure)

  defp available?(nil, :draft, claims, data_structure),
    do: permit?(StructureNotes, :edit, claims, data_structure)

  defp available?(nil, :ai_suggestions, claims, data_structure),
    do: permit?(StructureNotes, :ai_suggestions, claims, data_structure)

  defp available?(:draft, :edited, claims, data_structure),
    do: permit?(StructureNotes, :edit, claims, data_structure)

  defp available?(:draft, :ai_suggestions, claims, data_structure),
    do: permit?(StructureNotes, :ai_suggestions, claims, data_structure)

  defp available?(_, :pending_approval, claims, data_structure),
    do: permit?(StructureNotes, :submit, claims, data_structure)

  defp available?(_, :rejected, claims, data_structure),
    do: permit?(StructureNotes, :reject, claims, data_structure)

  defp available?(:rejected, :draft, claims, data_structure),
    do: permit?(StructureNotes, :unreject, claims, data_structure)

  defp available?(_, :draft, claims, data_structure),
    do: permit?(StructureNotes, :unreject, claims, data_structure)

  defp available?(_, :deprecated, claims, data_structure),
    do: permit?(StructureNotes, :deprecate, claims, data_structure)

  defp available?(_, :published, claims, data_structure),
    do: permit?(StructureNotes, :publish, claims, data_structure)

  defp available?(_, :deleted, claims, data_structure),
    do: permit?(StructureNotes, :delete, claims, data_structure)

  defp available?(_, _, _claims, _data_structure), do: false

  defp listable_statuses(claims, data_structure) do
    [
      {permit?(StructureNotes, :edit, claims, data_structure), [:draft]},
      {permit?(StructureNotes, :ai_suggestions, claims, data_structure), [:draft]},
      {permit?(StructureNotes, :submit, claims, data_structure), [:draft, :pending_approval]},
      {permit?(StructureNotes, :reject, claims, data_structure), [:pending_approval, :rejected]},
      {permit?(StructureNotes, :unreject, claims, data_structure), [:rejected, :draft]},
      {permit?(StructureNotes, :deprecate, claims, data_structure), [:deprecated]},
      {permit?(StructureNotes, :publish, claims, data_structure), [:pending_approval]},
      {permit?(StructureNotes, :delete, claims, data_structure), [:draft, :rejected]},
      {permit?(StructureNotes, :publish_draft, claims, data_structure), [:draft]},
      {permit?(StructureNotes, :history, claims, data_structure), [:versioned, :deprecated]},
      {permit?(DataStructures, :view_data_structure, claims, data_structure), [:published]}
    ]
    |> Enum.filter(fn {permission, _} -> permission end)
    |> Enum.flat_map(fn {_, statuses} -> statuses end)
    |> Enum.uniq()
  end
end
